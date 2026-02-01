# =============================================================================
# Karpenter Controller and Node Configuration
# =============================================================================
#
# Karpenter is a high-performance Kubernetes node autoscaler that provisions
# right-sized compute capacity in response to pending pods.
#
# This file creates:
#   - Karpenter Helm release
#   - EC2NodeClass (default and GPU)
#   - NodePools (general and GPU inference)
# =============================================================================

# =============================================================================
# KARPENTER CONTROLLER (Helm Release)
# =============================================================================
resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_version

  wait    = true
  timeout = 600

  values = [
    <<-EOT
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}

    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${module.karpenter.iam_role_arn}

    controller:
      resources:
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          cpu: 500m
          memory: 512Mi

    tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
        effect: NoSchedule

    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: workload
                  operator: In
                  values:
                    - system

    replicas: ${var.karpenter_replicas}
    EOT
  ]

  depends_on = [
    module.eks,
    module.karpenter
  ]
}

# =============================================================================
# EC2NodeClass: DEFAULT (for general CPU workloads)
# =============================================================================
resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiSelectorTerms:
        - alias: al2023@latest

      role: ${module.karpenter.node_iam_role_name}

      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${local.cluster_name}

      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${local.cluster_name}

      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: ${var.default_node_disk_size}Gi
            volumeType: gp3
            iops: 3000
            throughput: 125
            encrypted: true
            deleteOnTermination: true

      metadataOptions:
        httpEndpoint: enabled
        httpProtocolIPv6: disabled
        httpPutResponseHopLimit: 1
        httpTokens: required

      tags:
        Environment: ${var.environment}
        ManagedBy: Karpenter
        Project: ${var.project_name}
        karpenter.sh/discovery: ${local.cluster_name}
  YAML

  depends_on = [helm_release.karpenter]
}

# =============================================================================
# NodePool: GENERAL (default pool for most workloads)
# =============================================================================
resource "kubectl_manifest" "karpenter_node_pool_general" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: general
    spec:
      template:
        metadata:
          labels:
            nodepool: general
        spec:
          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: kubernetes.io/os
              operator: In
              values: ["linux"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ${jsonencode(var.general_pool_capacity_types)}
            - key: karpenter.k8s.aws/instance-category
              operator: In
              values: ${jsonencode(var.general_pool_instance_categories)}
            - key: karpenter.k8s.aws/instance-size
              operator: In
              values: ${jsonencode(var.general_pool_instance_sizes)}

          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default

          expireAfter: ${var.node_expire_after}

      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: ${var.consolidation_delay}

      limits:
        cpu: ${var.general_pool_cpu_limit}
        memory: ${var.general_pool_memory_limit}

      weight: 10
  YAML

  depends_on = [kubectl_manifest.karpenter_node_class]
}

# =============================================================================
# EC2NodeClass: GPU (for ML/AI inference workloads)
# =============================================================================
resource "kubectl_manifest" "karpenter_node_class_gpu" {
  count = var.enable_gpu_nodes ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: gpu
    spec:
      amiSelectorTerms:
        - alias: al2023@latest

      role: ${module.karpenter.node_iam_role_name}

      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${local.cluster_name}

      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${local.cluster_name}

      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: ${var.gpu_node_disk_size}Gi
            volumeType: gp3
            iops: 4000
            throughput: 200
            encrypted: true
            deleteOnTermination: true

      metadataOptions:
        httpEndpoint: enabled
        httpProtocolIPv6: disabled
        httpPutResponseHopLimit: 1
        httpTokens: required

      tags:
        Environment: ${var.environment}
        ManagedBy: Karpenter
        Project: ${var.project_name}
        NodeType: gpu
        karpenter.sh/discovery: ${local.cluster_name}
  YAML

  depends_on = [helm_release.karpenter]
}

# =============================================================================
# NodePool: GPU-INFERENCE (Scale-to-Zero)
# =============================================================================
resource "kubectl_manifest" "karpenter_node_pool_gpu" {
  count = var.enable_gpu_nodes ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: gpu-inference
    spec:
      template:
        metadata:
          labels:
            nodepool: gpu-inference
            nvidia.com/gpu.present: "true"
        spec:
          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: kubernetes.io/os
              operator: In
              values: ["linux"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ${jsonencode(var.gpu_pool_capacity_types)}
            - key: node.kubernetes.io/instance-type
              operator: In
              values: ${jsonencode(var.gpu_instance_types)}
            - key: karpenter.k8s.aws/instance-gpu-count
              operator: Gt
              values: ["0"]

          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: gpu

          taints:
            - key: nvidia.com/gpu
              value: "true"
              effect: NoSchedule

          expireAfter: ${var.node_expire_after}

      limits:
        cpu: ${var.gpu_pool_cpu_limit}
        memory: ${var.gpu_pool_memory_limit}
        nvidia.com/gpu: ${var.gpu_pool_gpu_limit}

      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: ${var.gpu_consolidation_delay}

      weight: 100
  YAML

  depends_on = [kubectl_manifest.karpenter_node_class_gpu]
}

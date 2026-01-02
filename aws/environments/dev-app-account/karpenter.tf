# =============================================================================
# Karpenter - Kubernetes Node Autoscaler
# =============================================================================
#
# What is Karpenter?
#   Karpenter is a high-performance Kubernetes node autoscaler that provisions
#   right-sized compute capacity in response to pending pods. Unlike Cluster
#   Autoscaler, Karpenter provisions individual nodes (not node groups) and
#   supports scale-to-zero for cost optimization.
#
# Why Karpenter instead of Cluster Autoscaler?
#   1. FASTER: Provisions nodes in ~60 seconds vs 3-5 minutes
#   2. FLEXIBLE: Right-sizes instances based on pod requirements
#   3. COST-EFFECTIVE: Supports scale-to-zero (no idle nodes)
#   4. SPOT-FRIENDLY: Handles spot interruptions gracefully via SQS
#   5. GPU-AWARE: Automatically selects GPU instances when pods request GPUs
#
# Architecture Overview:
#   ┌─────────────────────────────────────────────────────────────────────┐
#   │                         EKS CLUSTER                                  │
#   ├─────────────────────────────────────────────────────────────────────┤
#   │                                                                      │
#   │   SYSTEM NODES (Managed Node Group - Always On)                      │
#   │   ├── Karpenter Controller (this deployment)                         │
#   │   ├── CoreDNS, kube-proxy, vpc-cni                                   │
#   │   └── AWS Load Balancer Controller                                   │
#   │                                                                      │
#   │   APPLICATION NODES (Karpenter-Managed - Dynamic)                    │
#   │   ├── General NodePool: t3/m5/c5 instances (spot preferred)          │
#   │   └── GPU NodePool: g4dn instances (scale-to-zero)                   │
#   │                                                                      │
#   └─────────────────────────────────────────────────────────────────────┘
#
# How Karpenter Works:
#   1. Pod is created with resource requests (CPU, memory, GPU)
#   2. Scheduler cannot find a suitable node → Pod goes Pending
#   3. Karpenter detects pending pod
#   4. Karpenter evaluates NodePool constraints and selects instance type
#   5. Karpenter launches EC2 instance using EC2NodeClass configuration
#   6. Node joins cluster, pod is scheduled
#   7. When node is idle, Karpenter consolidates/terminates it
#
# Key Concepts:
#   - EC2NodeClass: Defines HOW nodes are created (AMI, storage, security)
#   - NodePool: Defines WHAT nodes can be created (instance types, limits)
#
# Dependencies:
#   - EKS cluster must be running (eks.tf)
#   - System nodes must be available for Karpenter controller
#   - Karpenter IAM roles created via terraform-aws-modules/eks//modules/karpenter
#   - Subnets and security groups tagged with karpenter.sh/discovery
#
# Related Files:
#   - eks.tf: EKS cluster and Karpenter IAM module
#   - nvidia-device-plugin.tf: GPU resource discovery (required for GPU nodes)
# =============================================================================


# =============================================================================
# KARPENTER CONTROLLER (Helm Release)
# =============================================================================
# The Karpenter controller watches for pending pods and provisions nodes.
# It runs on the system nodes (managed node group) for high availability.
#
# Why these settings?
#   - replicas: 2 for HA (leader election ensures only one is active)
#   - interruptionQueue: SQS queue for spot termination notices (2-min warning)
#   - tolerations: Allows running on tainted system nodes
#   - affinity: Forces scheduling on system nodes only
# =============================================================================
resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.0.8"

  # Wait for deployment to be ready before proceeding
  wait    = true
  timeout = 600

  values = [
    <<-EOT
    # Cluster configuration - tells Karpenter which cluster to manage
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      # SQS queue receives EC2 spot interruption warnings (2-min heads up)
      # Karpenter gracefully drains nodes before termination
      interruptionQueue: ${module.karpenter.queue_name}

    # IRSA: Karpenter assumes this IAM role to manage EC2 instances
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${module.karpenter.iam_role_arn}

    # Resource limits for the controller itself
    controller:
      resources:
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          cpu: 500m
          memory: 512Mi

    # Tolerate system node taint so Karpenter can run there
    tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
        effect: NoSchedule

    # Force Karpenter to run ONLY on system nodes (not Karpenter-managed nodes)
    # This prevents a chicken-and-egg problem where Karpenter needs to exist
    # before it can provision nodes for itself
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: workload
                  operator: In
                  values:
                    - system

    # 2 replicas for high availability (uses leader election)
    replicas: 2
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
# EC2NodeClass defines the "blueprint" for how nodes are created:
#   - Which AMI to use
#   - Which subnets/security groups
#   - EBS volume configuration
#   - Instance metadata settings
#
# This "default" class is used by the general and critical NodePools.
# =============================================================================
resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      # Amazon Linux 2023 - latest EKS-optimized AMI
      # AL2023 has better security defaults and longer support than AL2
      amiSelectorTerms:
        - alias: al2023@latest

      # IAM role for nodes - allows them to join the cluster
      role: ${module.karpenter.node_iam_role_name}

      # Subnet discovery - Karpenter finds subnets by this tag
      # These tags were applied in eks.tf
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${local.cluster_name}

      # Security group discovery - nodes get the cluster security group
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${local.cluster_name}

      # EBS root volume configuration
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: 50Gi        # Sufficient for containers and logs
            volumeType: gp3         # Best price/performance for general use
            iops: 3000              # gp3 baseline
            throughput: 125         # gp3 baseline (MiB/s)
            encrypted: true         # Security: encrypt data at rest
            deleteOnTermination: true

      # Instance metadata (IMDS) security settings
      metadataOptions:
        httpEndpoint: enabled
        httpProtocolIPv6: disabled
        httpPutResponseHopLimit: 1  # Prevents container escape to IMDS
        httpTokens: required        # IMDSv2 only - prevents SSRF attacks

      # Tags applied to EC2 instances
      tags:
        Environment: ${local.environment}
        ManagedBy: Karpenter
        Project: AltaNova
        karpenter.sh/discovery: ${local.cluster_name}
  YAML

  depends_on = [helm_release.karpenter]
}


# =============================================================================
# NodePool: GENERAL (default pool for most workloads)
# =============================================================================
# This is the primary NodePool for application workloads.
#
# Design decisions:
#   - SPOT FIRST: 70% cost savings, with on-demand fallback
#   - INSTANCE VARIETY: t3/m5/c5 families for diverse capacity pools
#   - FAST CONSOLIDATION: 1 minute - aggressive cost optimization for dev
#   - MODERATE LIMITS: 50 vCPU cap prevents runaway costs
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
          # Label for identifying which pool provisioned the node
          labels:
            nodepool: general
        spec:
          requirements:
            # Architecture: x86_64 only (ARM would need different AMI)
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: kubernetes.io/os
              operator: In
              values: ["linux"]

            # SPOT FIRST: Try spot instances, fall back to on-demand
            # Spot is ~70% cheaper but can be interrupted
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot", "on-demand"]

            # Instance families: burstable (t), general (m), compute (c)
            # Multiple families increase spot availability
            - key: karpenter.k8s.aws/instance-category
              operator: In
              values: ["t", "m", "c"]

            # Size limits: prevent accidentally launching huge instances
            - key: karpenter.k8s.aws/instance-size
              operator: In
              values: ["small", "medium", "large"]

          # Use the default EC2NodeClass for node configuration
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default

          # Force node replacement after 30 days
          # Ensures nodes get security patches and AMI updates
          expireAfter: 720h

      # Consolidation: Aggressively remove underutilized nodes
      # WhenEmptyOrUnderutilized: Remove if empty OR if pods can fit elsewhere
      # 1 minute is aggressive - good for dev, increase for prod
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 1m

      # Resource limits: Cap total resources this pool can provision
      # Prevents runaway costs if something goes wrong
      limits:
        cpu: 50
        memory: 100Gi

      # Weight: Lower number = lower priority
      # GPU pool has weight 100, so it's preferred for GPU workloads
      weight: 10
  YAML

  depends_on = [kubectl_manifest.karpenter_node_class]
}


# =============================================================================
# EC2NodeClass: GPU (for ML/AI inference workloads)
# =============================================================================
# Specialized node class for GPU instances.
#
# Key differences from default:
#   - LARGER STORAGE: 200Gi for model weights (LLMs can be 1-50GB each)
#   - HIGHER IOPS: Faster model loading from disk
#   - GPU TAG: For cost tracking and identification
# =============================================================================
resource "kubectl_manifest" "karpenter_node_class_gpu" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: gpu
    spec:
      # AL2023 with GPU support
      # The EKS-optimized AMI includes NVIDIA drivers
      amiSelectorTerms:
        - alias: al2023@latest

      role: ${module.karpenter.node_iam_role_name}

      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${local.cluster_name}

      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${local.cluster_name}

      # LARGER STORAGE for GPU workloads
      # LLM models can be 1-50GB each, plus container images
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: 200Gi       # 4x larger than default for model weights
            volumeType: gp3
            iops: 4000              # Higher IOPS for faster model loading
            throughput: 200         # Higher throughput (MiB/s)
            encrypted: true
            deleteOnTermination: true

      metadataOptions:
        httpEndpoint: enabled
        httpProtocolIPv6: disabled
        httpPutResponseHopLimit: 1
        httpTokens: required

      tags:
        Environment: ${local.environment}
        ManagedBy: Karpenter
        Project: AltaNova
        NodeType: gpu                # Tag for cost tracking
        karpenter.sh/discovery: ${local.cluster_name}
  YAML

  depends_on = [helm_release.karpenter]
}


# =============================================================================
# NodePool: GPU-INFERENCE (Scale-to-Zero for TinyLlama)
# =============================================================================
# GPU NodePool with SCALE-TO-ZERO capability for cost optimization.
#
# Cost Analysis (eu-west-1):
#   g4dn.xlarge On-Demand: $0.52/hr = $374/month (always on)
#   g4dn.xlarge Spot:      $0.16/hr = $115/month (always on)
#   g4dn.xlarge Spot + Scale-to-Zero: ~$10-30/month (2hr/day usage)
#
# Design decisions:
#   - SPOT PREFERRED: 70% cost savings on GPU instances
#   - SCALE-TO-ZERO: 5-minute consolidation removes idle GPU nodes
#   - TAINTED: nvidia.com/gpu taint prevents non-GPU pods from scheduling
#   - g4dn INSTANCES: T4 GPUs are cost-effective for inference
#
# How scale-to-zero works:
#   1. No GPU pods running → Node is empty
#   2. After 5 minutes idle, Karpenter terminates the node
#   3. When new GPU pod is created, Karpenter provisions new node (~60s)
#   4. NVIDIA device plugin discovers GPU and exposes nvidia.com/gpu resource
#   5. Pod is scheduled and runs inference
# =============================================================================
resource "kubectl_manifest" "karpenter_node_pool_gpu" {
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
            # Label indicating GPU presence (useful for monitoring)
            nvidia.com/gpu.present: "true"
        spec:
          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: kubernetes.io/os
              operator: In
              values: ["linux"]

            # SPOT PREFERRED with on-demand fallback
            # GPU spot instances can be harder to get, so allow fallback
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot", "on-demand"]

            # SPECIFIC GPU INSTANCE TYPES
            # g4dn: NVIDIA T4 GPUs - best cost/performance for inference
            - key: node.kubernetes.io/instance-type
              operator: In
              values:
                - "g4dn.xlarge"    # 1x T4 (16GB VRAM), 4 vCPU, 16GB RAM - $0.52/hr ($0.16 spot)
                - "g4dn.2xlarge"   # 1x T4 (16GB VRAM), 8 vCPU, 32GB RAM - $0.75/hr ($0.23 spot)

            # Ensure instance has at least 1 GPU
            - key: karpenter.k8s.aws/instance-gpu-count
              operator: Gt
              values: ["0"]

          # Use GPU-specific EC2NodeClass (larger storage)
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: gpu

          # GPU TAINT: Prevents non-GPU workloads from wasting GPU resources
          # Pods must have toleration: nvidia.com/gpu=true:NoSchedule
          taints:
            - key: nvidia.com/gpu
              value: "true"
              effect: NoSchedule

          expireAfter: 720h

      # RESOURCE LIMITS for GPU pool
      limits:
        cpu: 32
        memory: 128Gi
        nvidia.com/gpu: 4           # Max 4 GPUs total in this pool

      # SCALE-TO-ZERO CONFIGURATION
      # WhenEmpty: Only consolidate when no pods are running
      # 5 minutes: Wait before terminating to avoid thrashing
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 5m

      # HIGHEST PRIORITY: When pod requests GPU, use this pool first
      weight: 100
  YAML

  depends_on = [kubectl_manifest.karpenter_node_class_gpu]
}

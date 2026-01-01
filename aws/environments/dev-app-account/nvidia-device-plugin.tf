# =============================================================================
# NVIDIA Device Plugin for Kubernetes
# =============================================================================
#
# Purpose:
#   The NVIDIA device plugin is a DaemonSet that exposes GPUs as a schedulable
#   resource in Kubernetes. Without this plugin, pods cannot request GPUs using
#   the `nvidia.com/gpu` resource type.
#
# How it works:
#   1. Runs as a DaemonSet on nodes that have NVIDIA GPUs
#   2. Discovers GPU devices on each node
#   3. Reports GPU capacity to the Kubernetes scheduler via the device plugin API
#   4. Enables pods to request GPUs using: resources.limits["nvidia.com/gpu"]
#
# Why we need this:
#   - Karpenter provisions GPU nodes (g4dn instances with T4 GPUs)
#   - The NVIDIA device plugin makes those GPUs visible to Kubernetes
#   - Without it, pods requesting nvidia.com/gpu would remain Pending forever
#
# Integration with Karpenter GPU NodePool:
#   - GPU NodePool applies taint: nvidia.com/gpu=true:NoSchedule
#   - This plugin tolerates that taint so it can run on GPU nodes
#   - Once running, it exposes the GPU resource for workload pods
#
# Reference: https://github.com/NVIDIA/k8s-device-plugin
# =============================================================================

resource "helm_release" "nvidia_device_plugin" {
  namespace = "kube-system"
  name      = "nvidia-device-plugin"

  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  version    = "0.17.0"

  # Wait for deployment to complete before marking as successful
  wait    = true
  timeout = 300

  values = [
    <<-EOT
    # ---------------------------------------------------------------------------
    # Tolerations: Allow scheduling on GPU nodes that have taints
    # ---------------------------------------------------------------------------
    # GPU nodes are tainted to prevent non-GPU workloads from scheduling.
    # The device plugin must tolerate these taints to run on GPU nodes.
    tolerations:
      # Tolerate GPU node taint (from Karpenter GPU NodePool)
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      # Tolerate system node taint (in case plugin needs to run there)
      - key: CriticalAddonsOnly
        operator: Exists
        effect: NoSchedule

    # ---------------------------------------------------------------------------
    # Node Affinity: Only run on nodes that actually have GPUs
    # ---------------------------------------------------------------------------
    # This prevents the DaemonSet from running on non-GPU nodes where it
    # would serve no purpose. Karpenter labels GPU nodes automatically.
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                # Karpenter adds this label to nodes with GPUs
                - key: karpenter.k8s.aws/instance-gpu-count
                  operator: Gt
                  values: ["0"]

    # ---------------------------------------------------------------------------
    # Resource Limits: Keep the plugin lightweight
    # ---------------------------------------------------------------------------
    # The device plugin is a small daemon that doesn't need many resources.
    # Setting limits prevents it from consuming excessive node resources.
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        cpu: 100m
        memory: 128Mi
    EOT
  ]

  # Must wait for EKS cluster to be ready before installing
  depends_on = [module.eks]
}

# Dev Environment - AWS Load Balancer Controller
# Enables Kubernetes Ingress and Gateway API resources to create ALBs/NLBs
#
# This controller:
# - Watches for Ingress/Gateway resources
# - Automatically creates AWS Application Load Balancers
# - Integrates with ACM for TLS certificates
# - Supports target type: IP (for pods in VPC)
#
# After deployment, you can use:
# - Ingress (networking.k8s.io/v1)
# - Gateway API (gateway.networking.k8s.io/v1) with GatewayClass "aws-alb"

# -----------------------------------------------------------------------------
# IAM Role for AWS Load Balancer Controller (IRSA)
# -----------------------------------------------------------------------------
module "aws_lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.cluster_name}-aws-lb-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.eks_tags
}

# -----------------------------------------------------------------------------
# AWS Load Balancer Controller Helm Release
# -----------------------------------------------------------------------------
resource "helm_release" "aws_lb_controller" {
  namespace = "kube-system"

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.10.0"

  wait    = true
  timeout = 600

  values = [
    <<-EOT
    clusterName: ${module.eks.cluster_name}
    region: eu-west-1
    vpcId: ${module.vpc.vpc_id}

    serviceAccount:
      create: true
      name: aws-load-balancer-controller
      annotations:
        eks.amazonaws.com/role-arn: ${module.aws_lb_controller_irsa.iam_role_arn}

    # Run on system nodes
    tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
        effect: NoSchedule

    nodeSelector:
      workload: system

    # High availability
    replicaCount: 1

    # Enable Gateway API support
    enableServiceMutatorWebhook: true

    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi
    EOT
  ]

  depends_on = [
    module.eks,
    helm_release.karpenter
  ]
}

# -----------------------------------------------------------------------------
# Gateway API CRDs (optional - for Kubernetes Gateway API support)
# -----------------------------------------------------------------------------
# Uncomment to enable Gateway API
# resource "helm_release" "gateway_api_crds" {
#   namespace        = "gateway-system"
#   create_namespace = true
#
#   name       = "gateway-api"
#   repository = "https://charts.konghq.com"
#   chart      = "gateway-api"
#   version    = "1.2.0"
#
#   depends_on = [module.eks]
# }

# -----------------------------------------------------------------------------
# Example: Default IngressClass for ALB
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "alb_ingress_class" {
  yaml_body = <<-YAML
    apiVersion: networking.k8s.io/v1
    kind: IngressClass
    metadata:
      name: alb
      annotations:
        ingressclass.kubernetes.io/is-default-class: "true"
    spec:
      controller: ingress.k8s.aws/alb
  YAML

  depends_on = [helm_release.aws_lb_controller]
}

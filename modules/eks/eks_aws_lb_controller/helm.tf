resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.6.2"
  
  values = [
    yamlencode({
      clusterName = var.cluster_name
      region      = var.region
      vpcId       = var.vpc_id
      
      serviceAccount = {
        create = false
        name   = kubernetes_service_account_v1.aws_lb_controller.metadata[0].name
      }
      
      resources = {
        limits = {
          cpu    = "200m"
          memory = "500Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "200Mi"
        }
      }
      
      podLabels = {
        "app.kubernetes.io/name"       = "aws-load-balancer-controller"
        "app.kubernetes.io/component"  = "controller"
        "app.kubernetes.io/managed-by" = "terraform"
      }
      
      securityContext = {
        fsGroup = 65534
      }
      
      podSecurityContext = {
        runAsNonRoot = true
        runAsUser    = 65534
      }
    })
  ]
  
  depends_on = [
    aws_iam_role_policy_attachment.aws_lb_controller_attach,
    kubernetes_service_account_v1.aws_lb_controller
  ]
}

# Validate deployment
data "kubernetes_resource" "controller_deployment" {
  api_version = "apps/v1"
  kind        = "Deployment"
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
  }
  
  depends_on = [helm_release.aws_load_balancer_controller]
}

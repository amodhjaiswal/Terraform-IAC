

resource "null_resource" "argocd_ingress" {
  count = var.create_manifests ? 1 : 0

  triggers = {
    ingress_name = "${var.project_name}-${var.env_name}-argocd"
    region       = var.region
    cluster_name = var.eks_cluster_name
    namespace    = "argocd"
    manifest = jsonencode({
      apiVersion = "networking.k8s.io/v1"
      kind       = "Ingress"
      metadata = {
        name      = "${var.project_name}-${var.env_name}-argocd"
        namespace = "argocd"
        annotations = {
          "alb.ingress.kubernetes.io/scheme"             = "internet-facing"
          "alb.ingress.kubernetes.io/target-type"        = "ip"
          "alb.ingress.kubernetes.io/subnets"            = join(",", var.public_subnet_ids)
          "alb.ingress.kubernetes.io/load-balancer-name" = "k8s-${var.project_name}-${var.env_name}-alb"
          "alb.ingress.kubernetes.io/group.name"         = local.shared_group
          "alb.ingress.kubernetes.io/backend-protocol"   = "HTTP"
          "alb.ingress.kubernetes.io/listen-ports"       = jsonencode([{ HTTP = 80 }])
          "alb.ingress.kubernetes.io/success-codes"      = "200-499"
          "alb.ingress.kubernetes.io/tags"               = "Environment=${var.env_name},ManagedBy=terraform,Application=argocd"
        }
      }
      spec = {
        ingressClassName = "alb"
        rules = [{
          host = local.argocd_host
          http = {
            paths = [{
              path     = "/"
              pathType = "Prefix"
              backend = {
                service = {
                  name = "argocd-server"
                  port = { number = 80 }
                }
              }
            }]
          }
        }]
      }
    })
  }

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.region} --name ${var.eks_cluster_name} && echo '${self.triggers.manifest}' | kubectl apply -f - --validate=false"
  }

  depends_on = [null_resource.production_cleanup]
}
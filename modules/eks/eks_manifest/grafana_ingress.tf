locals {
  grafana_host = "grafana.${var.env_name}.${var.domain}"
  argocd_host  = "argocd.${var.env_name}.${var.domain}"
  shared_group = "${var.project_name}-${var.env_name}-shared-lb"
}

resource "null_resource" "grafana_ingress" {
  count = var.create_manifests ? 1 : 0

  triggers = {
    ingress_name = "${var.project_name}-${var.env_name}-grafana"
    region       = var.region
    cluster_name = var.eks_cluster_name
    namespace    = "monitoring"
    manifest = jsonencode({
      apiVersion = "networking.k8s.io/v1"
      kind       = "Ingress"
      metadata = {
        name      = "${var.project_name}-${var.env_name}-grafana"
        namespace = "monitoring"
        annotations = {
          "alb.ingress.kubernetes.io/group.name"       = local.shared_group
          "alb.ingress.kubernetes.io/target-type"      = "ip"
          "alb.ingress.kubernetes.io/healthcheck-path" = "/api/health"
          "alb.ingress.kubernetes.io/success-codes"    = "200-499"
        }
      }
      spec = {
        ingressClassName = "alb"
        rules = [{
          host = local.grafana_host
          http = {
            paths = [{
              path     = "/"
              pathType = "Prefix"
              backend = {
                service = {
                  name = "grafana"
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
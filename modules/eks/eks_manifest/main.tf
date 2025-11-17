locals {
  grafana_host = "grafana.${var.env_name}.${var.project_name}.com"
  argocd_host  = "argocd.${var.env_name}.${var.project_name}.com"
}

resource "null_resource" "grafana_ingress" {
  count = var.create_manifests ? 1 : 0

  triggers = {
    ingress_name = "${var.project_name}-${var.env_name}-grafana"
    manifest = jsonencode({
      apiVersion = "networking.k8s.io/v1"
      kind       = "Ingress"
      metadata = {
        name      = "${var.project_name}-${var.env_name}-grafana"
        namespace = "monitoring"
        annotations = {
          "alb.ingress.kubernetes.io/group.name"         = "${var.project_name}-${var.env_name}-shared-lb"
          "alb.ingress.kubernetes.io/target-type"        = "ip"
          "alb.ingress.kubernetes.io/healthcheck-path"   = "/api/health"
          "alb.ingress.kubernetes.io/success-codes"      = "200-499"
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

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete ingress ${self.triggers.ingress_name} -n monitoring --ignore-not-found=true"
  }

  depends_on = [var.aws_lb_controller, null_resource.argocd_ingress]
}

resource "null_resource" "argocd_ingress" {
  count = var.create_manifests ? 1 : 0

  triggers = {
    ingress_name = "${var.project_name}-${var.env_name}-argocd"
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
          "alb.ingress.kubernetes.io/load-balancer-name" = "${var.project_name}-${var.env_name}-alb"
          "alb.ingress.kubernetes.io/group.name"         = "${var.project_name}-${var.env_name}-shared-lb"
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

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete ingress ${self.triggers.ingress_name} -n argocd --ignore-not-found=true"
  }

  depends_on = [
    var.aws_lb_controller,
    var.argocd_deployment
  ]
}


###############################################
# PRODUCTION CLEANUP
###############################################

resource "null_resource" "production_cleanup" {
  count = var.create_manifests ? 1 : 0

  triggers = {
    region       = var.region
    vpc_id       = var.vpc_id
    cluster_name = var.eks_cluster_name
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      #!/bin/bash
      set -e

      echo "=== Starting Production Cleanup ==="

      aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name}

      # Delete Ingresses (safe)
      kubectl delete ingress -A --selector="ManagedBy=terraform" --ignore-not-found=true || true

      echo "--- Cleaning load balancers ---"
      for lb in $(aws elbv2 describe-load-balancers --region ${self.triggers.region} \
        --query "LoadBalancers[?VpcId=='${self.triggers.vpc_id}'].LoadBalancerArn" --output text); do
        aws elbv2 delete-load-balancer --load-balancer-arn $lb || true
      done

      sleep 30

      echo "--- Cleaning target groups ---"
      for tg in $(aws elbv2 describe-target-groups --region ${self.triggers.region} \
        --query "TargetGroups[?starts_with(TargetGroupName, 'k8s-')].TargetGroupArn" --output text); do
        aws elbv2 delete-target-group --target-group-arn $tg || true
      done

      sleep 20

      echo "--- Cleaning security groups ---"
      for sg in $(aws ec2 describe-security-groups --region ${self.triggers.region} \
        --filters "Name=vpc-id,Values=${self.triggers.vpc_id}" "Name=group-name,Values=k8s-*" \
        --query "SecurityGroups[].GroupId" --output text); do
        aws ec2 delete-security-group --group-id $sg || true
      done

      echo "=== Cleanup Completed ==="
    EOT
  }

  depends_on = [
    null_resource.grafana_ingress,
    null_resource.argocd_ingress
  ]
}

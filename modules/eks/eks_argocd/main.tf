# Namespace
resource "kubernetes_namespace_v1" "argocd" {
  count = var.create_manifests ? 1 : 0
  
  metadata {
    name = var.argocd_namespace
    labels = {
      "app.kubernetes.io/name"       = "argocd"
      "app.kubernetes.io/component"  = "namespace"
      "app.kubernetes.io/managed-by" = "terraform"
      "name"                         = var.argocd_namespace
    }
  }
  
  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      # Force cleanup of stuck resources in argocd namespace
      kubectl get targetgroupbindings -n argocd -o name | xargs -r kubectl patch -n argocd -p '{"metadata":{"finalizers":[]}}' --type=merge || true
      kubectl delete targetgroupbindings -n argocd --all --force --grace-period=0 || true
      
      # Remove finalizers from namespace if stuck
      kubectl patch namespace argocd -p '{"spec":{"finalizers":[]}}' --type=merge || true
    EOT
  }
}

# Namespace Labels
resource "kubernetes_labels" "argocd_namespace" {
  count = var.create_manifests ? 1 : 0
  
  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = kubernetes_namespace_v1.argocd[0].metadata[0].name
  }
  labels = {
    "pod-security.kubernetes.io/enforce" = "restricted"
    "pod-security.kubernetes.io/audit"   = "restricted"
    "pod-security.kubernetes.io/warn"    = "restricted"
  }
}

# ArgoCD Helm Release
resource "helm_release" "argocd" {
  count            = var.create_manifests ? 1 : 0
  name             = var.argocd_name
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version
  namespace        = kubernetes_namespace_v1.argocd[0].metadata[0].name
  create_namespace = false
  
  values = [
    yamlencode({
      controller = {
        resources = {
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "250m"
            memory = "256Mi"
          }
        }
        
        podSecurityContext = {
          runAsNonRoot = true
          runAsUser    = 999
          fsGroup      = 999
        }
      }
      
      server = {
        resources = {
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
        
        podSecurityContext = {
          runAsNonRoot = true
          runAsUser    = 999
          fsGroup      = 999
        }
        
        config = {
          "application.instanceLabelKey" = "argocd.argoproj.io/instance"
          "server.rbac.log.enforce.enable" = "true"
          "policy.default" = "role:readonly"
        }
      }
      
      repoServer = {
        resources = {
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
        
        podSecurityContext = {
          runAsNonRoot = true
          runAsUser    = 999
          fsGroup      = 999
        }
      }
      
      dex = {
        enabled = false
      }
      
      notifications = {
        enabled = false
      }
      
      applicationSet = {
        enabled = false
      }
      
      redis = {
        resources = {
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }
      
      crds = {
        keep = false
      }
    })
  ]
  
  depends_on = [
    kubernetes_namespace_v1.argocd,
    kubernetes_labels.argocd_namespace
  ]
}

# Validate ArgoCD Server Deployment
data "kubernetes_resource" "argocd_server" {
  count = var.create_manifests ? 1 : 0
  
  api_version = "apps/v1"
  kind        = "Deployment"
  metadata {
    name      = "${var.argocd_name}-server"
    namespace = kubernetes_namespace_v1.argocd[0].metadata[0].name
  }
  
  depends_on = [helm_release.argocd]
}

# Validate ArgoCD Controller StatefulSet (not Deployment)
data "kubernetes_resource" "argocd_controller" {
  count = var.create_manifests ? 1 : 0
  
  api_version = "apps/v1"
  kind        = "StatefulSet"
  metadata {
    name      = "${var.argocd_name}-application-controller"
    namespace = kubernetes_namespace_v1.argocd[0].metadata[0].name
  }
  
  depends_on = [helm_release.argocd]
}
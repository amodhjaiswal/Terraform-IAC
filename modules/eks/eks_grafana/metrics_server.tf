# Metrics Server for EKS cluster
resource "helm_release" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0

  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = var.metrics_server_chart_version

  values = [
    yamlencode({
      args = [
        "--cert-dir=/tmp",
        "--secure-port=4443",
        "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
        "--kubelet-use-node-status-port",
        "--metric-resolution=15s",
        "--kubelet-insecure-tls"
      ]

      securityContext = {
        allowPrivilegeEscalation = false
        readOnlyRootFilesystem   = true
        runAsNonRoot            = true
        runAsUser               = 1000
        seccompProfile = {
          type = "RuntimeDefault"
        }
      }

      containerPort = 4443
      
      resources = {
        limits = {
          cpu    = "100m"
          memory = "300Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "200Mi"
        }
      }

      nodeSelector = {
        "kubernetes.io/os" = "linux"
      }

      priorityClassName = "system-cluster-critical"
    })
  ]

  depends_on = [var.eks_cluster_endpoint]
}

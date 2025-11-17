# ServiceMonitor for metrics-server using null_resource to avoid REST client issues during plan
resource "null_resource" "metrics_server_servicemonitor" {
  count = var.enable_metrics_server && var.create_monitoring ? 1 : 0

  triggers = {
    manifest_content = yamlencode({
      apiVersion = "monitoring.coreos.com/v1"
      kind       = "ServiceMonitor"
      metadata = {
        name      = "metrics-server"
        namespace = "kube-system"
        labels = {
          "app.kubernetes.io/name" = "metrics-server"
        }
      }
      spec = {
        selector = {
          matchLabels = {
            "app.kubernetes.io/name" = "metrics-server"
          }
        }
        endpoints = [
          {
            port = "https"
            scheme = "https"
            tlsConfig = {
              insecureSkipVerify = true
            }
            bearerTokenFile = "/var/run/secrets/kubernetes.io/serviceaccount/token"
          }
        ]
      }
    })
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo '${yamlencode({
        apiVersion = "monitoring.coreos.com/v1"
        kind       = "ServiceMonitor"
        metadata = {
          name      = "metrics-server"
          namespace = "kube-system"
          labels = {
            "app.kubernetes.io/name" = "metrics-server"
          }
        }
        spec = {
          selector = {
            matchLabels = {
              "app.kubernetes.io/name" = "metrics-server"
            }
          }
          endpoints = [
            {
              port = "https"
              scheme = "https"
              tlsConfig = {
                insecureSkipVerify = true
              }
              bearerTokenFile = "/var/run/secrets/kubernetes.io/serviceaccount/token"
            }
          ]
        }
      })}' | kubectl apply -f -
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete servicemonitor metrics-server -n kube-system --ignore-not-found=true"
  }

  depends_on = [
    helm_release.metrics_server,
    helm_release.prometheus,
    kubernetes_namespace.monitoring
  ]
}

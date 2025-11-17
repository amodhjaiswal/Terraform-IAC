output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = var.create_manifests ? kubernetes_namespace_v1.argocd[0].metadata[0].name : null
}

output "argocd_service_name" {
  description = "ArgoCD server service name"
  value       = "${var.argocd_name}-server"
}

output "argocd_release_name" {
  description = "ArgoCD Helm release name"
  value       = var.argocd_name
}

output "helm_release_status" {
  description = "Status of the ArgoCD Helm release"
  value       = var.create_manifests ? helm_release.argocd[0].status : null
}

output "server_deployment_ready" {
  description = "ArgoCD server deployment readiness"
  value       = var.create_manifests ? try(data.kubernetes_resource.argocd_server[0].object.status.readyReplicas, 0) : null
}

output "controller_ready" {
  description = "ArgoCD controller readiness"
  value       = var.create_manifests ? try(data.kubernetes_resource.argocd_controller[0].object.status.readyReplicas, 0) : null
}

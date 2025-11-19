output "namespace_name" {
  description = "Name of the created namespace"
  value       = kubernetes_namespace.app_namespace.metadata[0].name
}

output "service_account_name" {
  description = "Name of the created service account"
  value       = kubernetes_service_account.app_service_account.metadata[0].name
}

output "pod_identity_association_id" {
  description = "Pod identity association ID"
  value       = aws_eks_pod_identity_association.app_pod_identity.association_id
}

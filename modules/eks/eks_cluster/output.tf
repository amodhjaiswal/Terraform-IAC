output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_security_group_id" {
  value = aws_security_group.eks_controlplane.id
}

output "node_group_name" {
  value = aws_eks_node_group.managed_nodes.node_group_name
}

output "node_role_arn" {
  value = aws_iam_role.node_group_role.arn
}

output "cluster_role_arn" {
  value = aws_iam_role.eks_cluster_role.arn
}

output "oidc_provider_arn" {
  value = var.create_oidc_provider && length(aws_iam_openid_connect_provider.oidc) > 0 ? aws_iam_openid_connect_provider.oidc[0].arn : null
}

output "oidc_url" {
  value = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "cluster_certificate_authority" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}


output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "pod_identity_role_arn" {
  value = var.create_oidc_provider && length(aws_iam_role.pod_identity_role) > 0 ? aws_iam_role.pod_identity_role[0].arn : null
}


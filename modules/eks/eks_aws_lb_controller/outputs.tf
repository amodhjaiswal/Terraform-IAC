output "aws_lb_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role"
  value       = aws_iam_role.aws_lb_controller_role.arn
}

output "service_account_name" {
  description = "Name of the AWS Load Balancer Controller service account"
  value       = kubernetes_service_account_v1.aws_lb_controller.metadata[0].name
}

output "helm_release_status" {
  description = "Status of the AWS Load Balancer Controller Helm release"
  value       = helm_release.aws_load_balancer_controller.status
}
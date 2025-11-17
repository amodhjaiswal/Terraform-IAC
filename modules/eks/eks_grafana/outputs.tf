output "loki_s3_bucket_name" {
  description = "Name of the S3 bucket used by Loki"
  value       = var.create_monitoring ? aws_s3_bucket.loki_logs[0].bucket : null
}

output "loki_s3_bucket_arn" {
  description = "ARN of the S3 bucket used by Loki"
  value       = var.create_monitoring ? aws_s3_bucket.loki_logs[0].arn : null
}

output "loki_iam_role_arn" {
  description = "ARN of the IAM role used by Loki"
  value       = var.create_monitoring ? aws_iam_role.loki_role[0].arn : null
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = var.create_monitoring ? aws_iam_role.ebs_csi_role[0].arn : null
}

output "monitoring_namespace" {
  description = "Kubernetes namespace for monitoring"
  value       = var.create_monitoring ? kubernetes_namespace.monitoring[0].metadata[0].name : null
}

output "storage_class_name" {
  description = "Name of the GP3 storage class"
  value       = var.create_monitoring ? kubernetes_storage_class.gp3[0].metadata[0].name : null
}

output "grafana_service_name" {
  description = "Name of the Grafana service"
  value       = var.create_monitoring ? "grafana" : null
}

output "prometheus_service_name" {
  description = "Name of the Prometheus service"
  value       = var.create_monitoring ? "prometheus-kube-prometheus-prometheus" : null
}

output "loki_service_name" {
  description = "Name of the Loki service"
  value       = var.create_monitoring ? "loki" : null
}

output "promtail_service_name" {
  description = "Name of the Promtail service"
  value       = var.create_monitoring ? "promtail" : null
}

output "metrics_server_status" {
  description = "Status of the metrics server deployment"
  value       = var.enable_metrics_server ? "enabled" : "disabled"
}

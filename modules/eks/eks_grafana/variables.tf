variable "create_monitoring" {
  description = "Whether to create monitoring resources"
  type        = bool
  default     = true
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "env_name" {
  description = "Environment name for resource naming"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC provider URL"
  type        = string
}

variable "storage_class_name" {
  description = "Storage class name for persistent volumes"
  type        = string
  default     = "gp3"
}

variable "loki_storage_size" {
  description = "Storage size for Loki"
  type        = string
  default     = "10Gi"
}

variable "prometheus_storage_size" {
  description = "Storage size for Prometheus"
  type        = string
  default     = "10Gi"
}

variable "grafana_storage_size" {
  description = "Storage size for Grafana"
  type        = string
  default     = "20Gi"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "loki_retention_period" {
  description = "Loki log retention period in hours"
  type        = string
  default     = "8760h"
}

variable "namespace" {
  description = "Kubernetes namespace for monitoring"
  type        = string
  default     = "monitoring"
}

variable "enable_metrics_server" {
  description = "Enable metrics server installation"
  type        = bool
  default     = true
}

variable "metrics_server_chart_version" {
  description = "Metrics server Helm chart version"
  type        = string
  default     = "3.12.1"
}

variable "enable_prometheus_monitoring" {
  description = "Enable Prometheus monitoring for metrics server"
  type        = bool
  default     = true
}

variable "promtail_storage_size" {
  description = "Storage size for Promtail PVC"
  type        = string
  default     = "5Gi"
}

variable "eks_cluster_endpoint" {
  description = "EKS cluster endpoint dependency"
  type        = any
  default     = null
}

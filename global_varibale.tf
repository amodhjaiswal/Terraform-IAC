variable "region" {
  description = "aws region where resouces are being deployed"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "env_name" {
  description = "Environment name (workspace)"
  type        = string
}

variable "aws_account_id" {
  description = "aws_account_id"
  type = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "create_manifests" {
  description = "Whether to create Kubernetes manifests (set to false for initial deployment)"
  type        = bool
  default     = true
}

# Monitoring variables
variable "create_monitoring" {
  description = "Whether to create monitoring resources"
  type        = bool
  default     = true
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

variable "promtail_storage_size" {
  description = "Storage size for Promtail"
  type        = string
  default     = "5Gi"
}

variable "domain" {
  description = "Domain name for ingress hosts"
  type        = string
}

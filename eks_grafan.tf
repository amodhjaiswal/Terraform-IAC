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
  default     = "10Gi"
}
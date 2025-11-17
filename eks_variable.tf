variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster (e.g. 1.29)"
  type        = string
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
}

variable "node_min_size" {
  description = "Minimum number of nodes in the EKS node group"
  type        = number
  default     = 1
}

variable "node_desired_size" {
  description = "Desired number of nodes in the EKS node group"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of nodes in the EKS node group"
  type        = number
  default     = 3
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






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

variable "domain" {
  description = "Domain name for ingress hosts"
  type        = string
}

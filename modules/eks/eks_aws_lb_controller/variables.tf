######################
# Variables
######################

variable "create_manifests" {
  type        = bool
  description = "Whether to create Kubernetes manifests"
  default     = true
}

variable "project_name" {
  type        = string
  description = "Project Name"
}

variable "env_name" {
  type        = string
  description = "Environment Name"
}

variable "cluster_name" {
  type        = string
  description = "EKS Cluster Name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "oidc_provider_arn" {
  type        = string
  description = "EKS OIDC Provider ARN"
}

variable "oidc_url" {
  type        = string
  description = "EKS OIDC Provider URL"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Common tags"
}





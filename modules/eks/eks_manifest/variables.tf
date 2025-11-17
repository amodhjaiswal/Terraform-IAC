variable "eks_cluster_name" {
  description = "EKS cluster name for dependency"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "aws_lb_controller" {
  description = "AWS Load Balancer Controller dependency"
  type        = any
}

variable "argocd_deployment" {
  description = "ArgoCD deployment dependency"
  type        = any
}

variable "vpc_id" {
  description = "VPC ID for security group cleanup"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "create_manifests" {
  description = "Whether to create Kubernetes manifests"
  type        = bool
  default     = true
}
variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "env_name" {
  description = "Environment name"
  type        = string
}

variable "domain" {
  description = "Domain name for ingress hosts"
  type        = string
}
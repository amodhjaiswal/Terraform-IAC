variable "project_name" {
  type        = string
  description = "Project name for naming resources"
}

variable "env_name" {
  type        = string
  description = "Environment name (dev/qa/prod) for naming"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where EKS will be deployed"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for cluster and nodes"
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes version for EKS cluster (e.g. 1.29)"
}

variable "node_instance_type" {
  type        = string
  description = "EC2 instance type for worker nodes"
}

variable "node_root_volume_size" {
  type        = number
  description = "Root EBS volume size in GiB for worker nodes"
  default     = 50
}

variable "root_device_name" {
  type        = string
  description = "Root device name for nodes"
  default     = "/dev/xvda"
}

variable "node_min_size" {
  type        = number
  default     = 1
}

variable "node_max_size" {
  type        = number
  default     = 2
}

variable "node_desired_size" {
  type        = number
  default     = 2
}

variable "node_capacity_type" {
  type        = string
  default     = "ON_DEMAND"
}

variable "node_labels" {
  type        = map(string)
  default     = {}
}

variable "enable_cluster_autoscaler" {
  type        = bool
  default     = false
}

variable "attach_ssm_managed_policy" {
  type        = bool
  default     = true
}

variable "create_oidc_provider" {
  type        = bool
  default     = true
}

variable "oidc_thumbprint" {
  type        = string
  default     = "6938fd4d98bab03faadb97b34396831e3780aea1"
}
variable "codebuild_role_arn" {
  type        = string
}
variable "bastion_ssm_role_arn" {
  type        = string
}
variable "bastion_sg_id" {
  type        = string
}

variable "tags" {
  type        = map(string)
  default     = {}
}

variable "region" {
  description = "aws region where resouces are being deployed"
  type        = string
}
variable "secret_arn" {
  description = "secret_arn"
  type        = string
}
variable "bucket_name" {
  description = "bucket_name"
  type        = string
}


variable "project_name" {
  description = "Project name"
  type        = string
}

variable "env_name" {
  description = "Environment name (workspace)"
  type        = string
}


variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR for SG access"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Redis"
  type        = list(string)
}

variable "node_type" {
  description = "Elasticache Redis node type/size (e.g., cache.t3.medium)"
  type        = string
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "engine_version_major" {
  description = "Major Redis version for parameter group"
  type        = string
  default     = "7"
}

variable "multi_az" {
  description = "Enable Multi-AZ"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default     = {}
}

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
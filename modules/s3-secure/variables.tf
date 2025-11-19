variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "env_name" {
  description = "Environment name"
  type        = string
}

variable "bucket_suffix" {
  description = "Suffix for the bucket name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "enable_cross_region_replication" {
  description = "Enable cross-region replication"
  type        = bool
  default     = false
}

variable "replication_destination_bucket_arn" {
  description = "ARN of the destination bucket for replication"
  type        = string
  default     = ""
}

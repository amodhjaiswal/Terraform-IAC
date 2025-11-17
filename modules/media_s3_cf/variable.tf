variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
}

variable "env_name" {
  description = "Environment name (e.g., dev, prod) for resource naming"
  type        = string
}

variable "media_bucket_name" {
  description = "Frontend identifier for S3 bucket naming"
  type        = string
}

variable "default_root_object" {
  description = "Default root object for CloudFront"
  type        = string
  default     = "index.html"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
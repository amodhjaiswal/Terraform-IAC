variable "frontend_bucket_name" {
  description = "Name of frontend s3 bucket"
  type        = string
}

variable "default_root_object" {
  description = "Default root object for CloudFront"
  type        = string
  default     = "index.html"
}
variable "project_name" {
  description = "Project name"
  type        = string
}

variable "env_name" {
  description = "Environment name (e.g. dev, qa, prod)"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

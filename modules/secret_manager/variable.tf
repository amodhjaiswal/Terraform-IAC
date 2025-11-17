variable "project_name" {
  description = "Project name"
  type        = string
}

variable "env_name" {
  description = "Environment name (e.g., dev, qa, prod)"
  type        = string
}

# variable "secret_string" {
#   description = "Secret value as a string (JSON format recommended)"
#   type        = string
# }

variable "tags" {
  description = "Tags for the secret"
  type        = map(string)
  default     = {}
}

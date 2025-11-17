###########----------GLOBAL VARIABLE---------###########
variable "env_name" {
  description = "Environment name (workspace)"
  type        = string
}
variable "project_name" {
  description = "Environment name (workspace)"
  type        = string
}


###########----------VPC VARIABLE---------###########
variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "vpc"
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability Zones to use"
  type        = list(string)
}
variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "VPC ID for the bastion host"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed to SSH to bastion"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "key_pair_name" {
  description = "Name of the EC2 key pair for SSH access"
  type        = string
  default     = null
}

variable "public_subnet" {
  description = "Subnet ID for the bastion host"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the bastion host"
  type        = string
}

variable "instance_type" {
  description = "Instance type for the bastion host"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "env_name" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "instance_name" {
  description = "Name of the bastion instance"
  type        = string
}
variable "bastion_ebs_size" {
  description = "size of ebs volume"
  type        = number
}

variable "tags" {
  description = "Tags for the instance"
  type        = map(string)
}

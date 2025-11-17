variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "instance_name" {
  type = string
}
variable "bastion_ebs_size" {
  description = "size of ebs volume"
  type        = number
}

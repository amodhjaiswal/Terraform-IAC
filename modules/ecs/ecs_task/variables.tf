################ Variables ################
variable "project_name" {
type = string
}
variable "env_name" {
type = string
}
variable "ecs_cluster_id" {
type = string
}
variable "execution_role_arn" {
type = string
}
variable "task_role_arn" {
type = string
}
variable "vpc_id" {
type = string
}
variable "private_subnets" {
type = list(string)
}
variable "ecr_repository_url" {
type = string
}
variable "target_group_arn" {
type = string
}
variable "tags" {
type = map(string)
}
variable "alb_sg_id" {
description = "ALB Security Group ID"
type        = string
}
variable "port" {
type = string
}
variable "service_name" {
type = string
}
variable "region" {
type = string
}

variable "ecs_cpu" {
type = string
}

variable "ecs_memory" {
type = string
}

variable "ecs_task_count" {
type = number
}


locals {
  ecs_pipelines = {
    app1 = {
      service_name = var.ecs_service_name_1
      port         = var.ecs_service_port_1
    }
    app2 = {
      service_name = var.ecs_service_name_2
      port         = var.ecs_service_port_2
    }
  }
}

variable "ecs_service_name_1" {
  type = string
}

variable "ecs_service_name_2" {
  type = string
}

variable "ecs_service_port_1" {
  type = number
}

variable "ecs_service_port_2" {
  type = number
}

locals {
  pipelines = {
    app1 = {
      service_name = var.service_name_1
    }
    app2 = {
      service_name = var.service_name_2
    }
  }
}

variable "service_name_1" {
  type = string
}

variable "service_name_2" {
  type = string
}









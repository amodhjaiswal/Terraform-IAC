variable "project_name" {
type = string
}
variable "env_name" {
type = string
}
variable "vpc_id" {
type = string
}
variable "public_subnets" {
type = list(string)
}
variable "tags" {
type = map(string)
}
variable "service_name" {
type = string
}
variable "port" {
type = string
}
variable "project_name" {
  type = string
}

variable "env_name" {
  type = string
}

variable "eks_cluster_name" {
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "service_name" {
  type        = string
  description = "Service name for the pipeline"
}

# Global module inputs
variable "artifact_bucket_name" {
  type        = string
  description = "Artifact bucket name from global module"
}

variable "codepipeline_role_arn" {
  type        = string
  description = "CodePipeline role ARN from global module"
}

variable "codebuild_role_arn" {
  type        = string
  description = "CodeBuild role ARN from global module"
}
#############################################
# Locals
#############################################
locals {
  name_prefix = "${var.project_name}-${var.env_name}"
  tags = merge(
    {
      Name        = local.name_prefix
      Project     = var.project_name
      Environment = var.env_name
    },
    var.tags
  )
}

#############################################
# CodePipeline
#############################################
resource "aws_codepipeline" "this" {
  name     = "${local.name_prefix}-${var.service_name}"
  role_arn = var.codepipeline_role_arn

  artifact_store {
    location = var.artifact_bucket_name
    type     = "S3"
  }

  # Source Stage (hardcoded sample values)
  stage {
    name = "Source"
    action {
      name            = "Source"
      category        = "Source"
      owner           = "AWS"
      provider        = "CodeCommit"
      version         = "1"
      output_artifacts = ["source_output"]
      configuration = {
        RepositoryName = "example-repo"
        BranchName     = "main"
      }
    }
  }

  # Build Stage
  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"
      configuration = {
        ProjectName = "${local.name_prefix}-${var.service_name}-codebuild"
      }
    }
  }

  tags = local.tags
}

#############################################
# CloudWatch Logs for CodePipeline
#############################################
resource "aws_cloudwatch_log_group" "pipeline_logs" {
  name              = "/aws/codepipeline/${local.name_prefix}-${var.service_name}"
  retention_in_days = 30
  tags              = local.tags
}
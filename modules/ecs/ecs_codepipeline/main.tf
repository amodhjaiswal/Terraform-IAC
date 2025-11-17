#############################################
# Locals
#############################################
locals {
  name_prefix = "${var.project_name}-${var.env_name}"

  tags = merge(
    {
      Name        = "${local.name_prefix}-${var.service_name}"
      Project     = var.project_name
      Environment = var.env_name
      Service     = var.service_name
    },
    var.tags
  )
}

#############################################
# CodePipeline
#############################################
resource "aws_codepipeline" "this" {
  name     = "${local.name_prefix}-${var.service_name}-pipeline"
  role_arn = var.codepipeline_role_arn

  artifact_store {
    location = var.artifact_bucket_name
    type     = "S3"
  }

  # Source Stage: Pulls code from CodeCommit
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        RepositoryName = "${var.project_name}-${var.service_name}-repo"
        BranchName     = "main"
      }
    }
  }

  # Build Stage: Builds the application using CodeBuild
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
        ProjectName = aws_codebuild_project.this.name
      }
    }
  }

  # Deploy Stage: Deploys to ECS
  stage {
    name = "Deploy"
    action {
      name            = "Deploy-to-ECS"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["build_output"]
      version         = "1"
      configuration = {
        ClusterName = "${local.name_prefix}-ecs-cluster"
        ServiceName = "${var.project_name}-${var.env_name}-${var.service_name}-service"
        FileName    = "imagedefinitions.json"
      }
    }
  }

  tags = local.tags
  # depends_on = [aws_ecs_service.service]
}


#############################################
# CloudWatch Logs for CodePipeline
#############################################
resource "aws_cloudwatch_log_group" "pipeline_logs" {
  name              = "/aws/codepipeline/${local.name_prefix}-${var.service_name}"
  retention_in_days = 30
  tags              = local.tags
}
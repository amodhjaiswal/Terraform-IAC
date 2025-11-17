#############################################
# CodeBuild Project
#############################################
resource "aws_codebuild_project" "this" {
  name         = "${local.name_prefix}-${var.service_name}-codebuild"
  description  = "CodeBuild project for ${var.service_name}"
  service_role = var.codebuild_role_arn

  artifacts {
    type = "CODEPIPELINE"
    name = "build_output"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_LARGE"
    image           = "aws/codebuild/standard:6.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "CONTAINER_NAME"
      value = var.service_name
    }
    environment_variable {
      name  = "CONTAINER_PORT"
      value = var.port
    }
    environment_variable {
      name  = "ECR_REGION"
      value = var.region
    }
    environment_variable {
      name  = "ECR_URI"
      value = var.ecr_repository_url
    }
  }

  source {
    type = "CODEPIPELINE"

    buildspec = <<EOF
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: 22
    commands:
      - echo "Installing dependencies if any..."

  pre_build:
    commands:
      - echo "Logging in to Amazon ECR..."
      - aws ecr get-login-password --region $ECR_REGION | docker login --username AWS --password-stdin $ECR_URI

      - echo "Generating commit hash and image tag..."
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG="$CONTAINER_NAME-$COMMIT_HASH"
      - echo "Image tag set to $IMAGE_TAG"

  build:
    commands:
      - echo "Building Docker image using python:3.10-slim..."
      - docker build -t $CONTAINER_NAME:latest -f ./Dockerfile .
      - echo "Tagging image..."
      - docker tag $CONTAINER_NAME:latest $ECR_URI:$IMAGE_TAG
      - echo "Pushing image to ECR..."
      - docker push $ECR_URI:$IMAGE_TAG

  post_build:
    commands:
      - echo "Build completed on $(date)"
      - echo "Creating imagedefinitions.json for CodePipeline..."
      - printf '[{"name":"%s","imageUri":"%s"}]' $CONTAINER_NAME $ECR_URI:$IMAGE_TAG > imagedefinitions.json
      - cat imagedefinitions.json

artifacts:
  files:
    - imagedefinitions.json
EOF
  }

  tags = local.tags
}
#######################################
# AWS CodeBuild Project
#######################################

resource "aws_codebuild_project" "this" {
  name         = "${local.name_prefix}-${var.service_name}-codebuild"
  description  = "CodeBuild project for ${var.service_name}"
  service_role = var.codebuild_role_arn

  artifacts {
    type = "CODEPIPELINE"
    name = "build_output"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_LARGE" # 8 vCPUs, 16 GiB
    image           = "aws/codebuild/standard:6.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.aws_account_id
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.region
    }
    environment_variable {
      name  = "PROJECT_NAME"
      value = var.project_name
    }
    environment_variable {
      name  = "ENV_NAME"
      value = var.env_name
    }
    environment_variable {
      name  = "EKS_CLUSTER_NAME"
      value = var.eks_cluster_name
    }
    environment_variable {
      name  = "SERVICE_NAME"
      value = var.service_name
    }
  }

  # Inline build commands (instead of buildspec.yml)
  source {
    type = "CODEPIPELINE"

    buildspec = <<EOF
version: 0.2

phases:
  pre_build:
    commands:
      - echo "Logging in to Amazon ECR..."
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com

  build:
    commands:
      - echo "Build started on $(date)"
      - echo "Building Docker image..."
      # - docker build -t $PROJECT_NAME-$ENV_NAME-app .
      # - docker tag $PROJECT_NAME-$ENV_NAME-app:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG

  post_build:
    commands:
      - echo "Pushing image to ECR..."
      # - docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG
      # - echo "Writing image definitions..."
      # - printf '[{"name":"%s","imageUri":"%s"}]' "$PROJECT_NAME-$ENV_NAME-app" "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG" > imagedefinitions.json

      # ✅ Install kubectl
      # ✅ Install latest stable kubectl (official method)
      - echo "Installing kubectl..."
      - export KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
      - curl -LO "https://dl.k8s.io/release/v1.34.0/bin/linux/amd64/kubectl"
      - curl -LO "https://dl.k8s.io/release/v1.34.0/bin/linux/amd64/kubectl.sha256"
      - echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
      - chmod +x kubectl
      - mv kubectl /usr/local/bin/kubectl
      - echo "Verifying kubectl installation..."
      - kubectl version --client



      # ✅ Update kubeconfig and deploy
      - echo "Updating kubeconfig for EKS cluster..."
      - aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $AWS_DEFAULT_REGION
      - echo "Applying Kubernetes manifests..."
      - kubectl get nodes
      - kubectl apply -f .k8s/

artifacts:
  files:
    - imagedefinitions.json
EOF
  }

  tags = local.tags
}

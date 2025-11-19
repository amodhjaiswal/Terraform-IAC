# Secure IAM policies for CodePipeline - replaces overprivileged policies in iam.tf

# Data sources for resource ARNs
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Secure CodePipeline policy with specific resource constraints
resource "aws_iam_role_policy" "codepipeline_policy_secure" {
  name = "${local.name_prefix}-codepipeline-policy-secure"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = "arn:aws:codebuild:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:project/${local.name_prefix}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:GetRepository",
          "codecommit:ListBranches",
          "codecommit:ListRepositories"
        ]
        Resource = "arn:aws:codecommit:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:${var.project_name}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService"
        ]
        Resource = [
          "arn:aws:ecs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:cluster/${local.name_prefix}-*",
          "arn:aws:ecs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:service/${local.name_prefix}-*",
          "arn:aws:ecs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:task-definition/${local.name_prefix}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.name_prefix}-*"
      }
    ]
  })
}

# Secure CodeBuild policy with specific resource constraints
resource "aws_iam_role_policy" "codebuild_policy_secure" {
  name = "${local.name_prefix}-codebuild-policy-secure"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken"
        ]
        Resource = [
          "arn:aws:ecr:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:repository/${local.name_prefix}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.artifacts.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.name_prefix}-*"
      }
    ]
  })
}

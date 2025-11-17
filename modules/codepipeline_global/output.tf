# IAM Roles
output "codepipeline_role_arn" {
  description = "ARN of the IAM role for CodePipeline"
  value       = aws_iam_role.codepipeline_role.arn
}

output "codebuild_role_arn" {
  description = "ARN of the IAM role for CodeBuild"
  value       = aws_iam_role.codebuild_role.arn
}

# S3 Bucket
output "artifact_bucket_name" {
  description = "Name of the S3 bucket for CodePipeline artifacts"
  value       = aws_s3_bucket.artifacts.bucket
}

output "artifact_bucket_arn" {
  description = "ARN of the S3 bucket for CodePipeline artifacts"
  value       = aws_s3_bucket.artifacts.arn
}
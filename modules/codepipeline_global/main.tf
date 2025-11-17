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

resource "random_integer" "bucket_suffix" {
  min = 1000
  max = 9999
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "${local.name_prefix}-codepipeline-${random_integer.bucket_suffix.result}"

  force_destroy = true   # <--- Ensures bucket is deleted even if it contains objects

  tags = local.tags
}

# Enable default encryption with SSE-KMS (default AWS key) + bucket key
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"   # use SSE-KMS
      kms_master_key_id = "aws/s3"    # default AWS managed key for S3
    }

    bucket_key_enabled = true
  }
}

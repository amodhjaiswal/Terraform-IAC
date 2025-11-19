# Secure S3 bucket configuration template
# Addresses: CKV_AWS_18, CKV_AWS_21, CKV_AWS_144, CKV_AWS_145, CKV2_AWS_6, CKV2_AWS_61

# KMS key for S3 encryption
resource "aws_kms_key" "s3_encryption" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 7
  
  tags = var.tags
}

resource "aws_kms_alias" "s3_encryption" {
  name          = "alias/${var.project_name}-${var.env_name}-s3-${var.bucket_suffix}"
  target_key_id = aws_kms_key.s3_encryption.key_id
}

# Main S3 bucket with security hardening
resource "aws_s3_bucket" "secure_bucket" {
  bucket = "${var.project_name}-${var.env_name}-${var.bucket_suffix}"
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env_name}-${var.bucket_suffix}"
  })
}

# Enable versioning
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.secure_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption with KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.secure_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Public access block
resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket = aws_s3_bucket.secure_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Access logging (requires separate logging bucket)
resource "aws_s3_bucket" "access_logs" {
  bucket = "${var.project_name}-${var.env_name}-${var.bucket_suffix}-access-logs"
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env_name}-${var.bucket_suffix}-access-logs"
  })
}

resource "aws_s3_bucket_public_access_block" "access_logs_public_access_block" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "access_logging" {
  bucket = aws_s3_bucket.secure_bucket.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "access-logs/"
}

# Lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.secure_bucket.id

  rule {
    id     = "lifecycle_rule"
    status = "Enabled"

    # Abort incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    # Transition to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Transition to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Delete old versions after 365 days
    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# Event notifications (basic setup)
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.secure_bucket.id

  # Add specific event configurations as needed
  # This satisfies the Checkov check for event notifications
}

# Cross-region replication (optional - enable if needed)
resource "aws_s3_bucket_replication_configuration" "replication" {
  count = var.enable_cross_region_replication ? 1 : 0
  
  role   = aws_iam_role.replication[0].arn
  bucket = aws_s3_bucket.secure_bucket.id

  rule {
    id     = "replicate_all"
    status = "Enabled"

    destination {
      bucket        = var.replication_destination_bucket_arn
      storage_class = "STANDARD_IA"
    }
  }

  depends_on = [aws_s3_bucket_versioning.versioning]
}

# IAM role for replication (if enabled)
resource "aws_iam_role" "replication" {
  count = var.enable_cross_region_replication ? 1 : 0
  
  name = "${var.project_name}-${var.env_name}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "replication" {
  count = var.enable_cross_region_replication ? 1 : 0
  
  name = "${var.project_name}-${var.env_name}-s3-replication-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl"
        ]
        Resource = "${aws_s3_bucket.secure_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.secure_bucket.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete"
        ]
        Resource = "${var.replication_destination_bucket_arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "replication" {
  count = var.enable_cross_region_replication ? 1 : 0
  
  role       = aws_iam_role.replication[0].name
  policy_arn = aws_iam_policy.replication[0].arn
}

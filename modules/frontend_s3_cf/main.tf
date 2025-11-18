# Generating a random 4-digit number for unique S3 bucket name
resource "random_integer" "bucket_suffix" {
  min = 1000
  max = 9999
}

# Defining the S3 bucket resource with unique naming convention and force_destroy
resource "aws_s3_bucket" "bucket" {
  bucket        = "${var.project_name}-${var.env_name}-${var.frontend_bucket_name}-${random_integer.bucket_suffix.result}"
  force_destroy = true # Allows deletion even if bucket contains objects
}

# Disabling ACL for the S3 bucket
resource "aws_s3_bucket_ownership_controls" "bucket_ownership" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Disabling versioning for the S3 bucket
resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status = "Disabled"
  }
}

# Enabling server-side encryption with SSE-S3
resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_encryption" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # SSE-S3 uses AES256
    }
    bucket_key_enabled = true # Enabling Bucket Key (not applicable for SSE-S3, but included for consistency)
  }
}

# CORS configuration for the S3 bucket
resource "aws_s3_bucket_cors_configuration" "bucket_cors" {
  bucket = aws_s3_bucket.bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["POST", "GET", "HEAD", "DELETE", "PUT"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag", "x-amz-server-side-encryption", "x-amz-request-id", "x-amz-meta-custom-header", "x-amz-id-2"]
    max_age_seconds = 3000
  }
}

# Adding lifecycle rule to empty bucket on destruction
resource "aws_s3_bucket_lifecycle_configuration" "bucket_lifecycle" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    id     = "expire-all-objects"
    status = "Enabled"
    filter {
      prefix = "" # Empty prefix applies to all objects in the bucket
    }
    expiration {
      days = 0 # Expire objects immediately (on next lifecycle run)
    }
    noncurrent_version_expiration {
      noncurrent_days = 1 # Safety for non-versioned buckets, though versioning is disabled
    }
  }
}

# Defining bucket policy to allow CloudFront access
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontAccess"
        Effect    = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.oai.iam_arn
        }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.bucket.arn}/*"
      }
    ]
  })
}

# Creating CloudFront origin access identity
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "${var.project_name}-${var.env_name}-cloudfront-oai"
}

# Defining CloudFront distribution with custom error response
resource "aws_cloudfront_distribution" "distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = "${var.project_name}-${var.env_name}-${var.frontend_bucket_name}-s3-origin"
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.default_root_object

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.project_name}-${var.env_name}-${var.frontend_bucket_name}-s3-origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl               = 0
    default_ttl           = 3600
    max_ttl               = 86400
  }

  # Adding custom error response for 403 errors
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env_name}-cloudfront"
  })
}
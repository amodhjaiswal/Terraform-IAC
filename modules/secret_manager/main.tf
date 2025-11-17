# Generating a random 4-digit number for unique S3 bucket name
resource "random_integer" "bucket_suffix" {
  min = 1000
  max = 9999
}

resource "aws_secretsmanager_secret" "this" {
  name        = "${var.project_name}-${var.env_name}-backend--${random_integer.bucket_suffix.result}"
  description = "secret manager to store backend secrets"

  tags = var.tags
}

# resource "aws_secretsmanager_secret_version" "this" {
#   secret_id     = aws_secretsmanager_secret.this.id
#   secret_string = var.secret_string
# }

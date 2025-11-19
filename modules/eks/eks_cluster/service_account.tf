# Data sources for OIDC provider
data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.this_secure.name
  depends_on = [
    aws_eks_cluster.this_secure,
    aws_eks_node_group.managed_nodes
  ]
}

data "aws_iam_openid_connect_provider" "cluster" {
  count = var.create_oidc_provider ? 1 : 0
  arn   = aws_iam_openid_connect_provider.oidc[0].arn
}

# IAM Role for Pod Identity
resource "aws_iam_role" "pod_identity_role" {
  count = var.create_oidc_provider ? 1 : 0
  name  = "${var.project_name}-${var.env_name}-pod-identity-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      },
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.cluster[0].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:${var.env_name}:${var.project_name}-${var.env_name}-service-account"
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.env_name}-pod-identity-role"
    Environment = var.env_name
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# Inline policy for Secrets Manager and S3 access
resource "aws_iam_role_policy" "pod_identity_policy" {
  count = var.create_oidc_provider ? 1 : 0
  name  = "${var.project_name}-${var.env_name}-pod-identity-policy"
  role  = aws_iam_role.pod_identity_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.region}:*:secret:amodh*"
      },
      {
        Effect = "Allow"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::amodh-s3",
          "arn:aws:s3:::amodh-s3/*"
        ]
      }
    ]
  })
}

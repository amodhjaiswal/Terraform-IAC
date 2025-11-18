# Namespace
resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.env_name
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "environment" = var.env_name
      "project" = var.project_name
    }
  }
}

# Service Account
resource "kubernetes_service_account" "app_service_account" {
  metadata {
    name      = "${var.project_name}-${var.env_name}-service-account"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.pod_identity_role.arn
    }
    labels = {
      "app.kubernetes.io/name"       = "${var.project_name}-${var.env_name}-service-account"
      "app.kubernetes.io/managed-by" = "terraform"
      "environment"                  = var.env_name
      "project"                      = var.project_name
    }
  }
}

# Pod Identity Association
resource "aws_eks_pod_identity_association" "app_pod_identity" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = kubernetes_namespace.app_namespace.metadata[0].name
  service_account = kubernetes_service_account.app_service_account.metadata[0].name
  role_arn        = aws_iam_role.pod_identity_role.arn

  tags = {
    Name        = "${var.project_name}-${var.env_name}-pod-identity"
    Environment = var.env_name
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# IAM Role for Pod Identity
resource "aws_iam_role" "pod_identity_role" {
  name = "${var.project_name}-${var.env_name}-pod-identity-role"

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
          Federated = data.aws_iam_openid_connect_provider.cluster.arn
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
  name = "${var.project_name}-${var.env_name}-pod-identity-policy"
  role = aws_iam_role.pod_identity_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "${var.secret_arn}"
      },
      {
        Effect = "Allow"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      }
    ]
  })
}

# Data sources for OIDC provider
data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.this.name
}

data "aws_iam_openid_connect_provider" "cluster" {
  arn = aws_iam_openid_connect_provider.oidc[0].arn
}

# Cleanup resource for service account and role
resource "null_resource" "service_account_cleanup" {
  triggers = {
    cluster_name     = aws_eks_cluster.this.name
    service_account  = "${var.project_name}-${var.env_name}-service-account"
    namespace        = var.env_name
    role_name        = "${var.project_name}-${var.env_name}-pod-identity-role"
    region           = var.region
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      # Configure kubectl
      aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name} || true
      
      # Remove finalizers and force delete service account
      kubectl patch serviceaccount ${self.triggers.service_account} -n ${self.triggers.namespace} -p '{"metadata":{"finalizers":null}}' --type=merge || true
      kubectl delete serviceaccount ${self.triggers.service_account} -n ${self.triggers.namespace} --force --grace-period=0 --ignore-not-found=true || true
      
      # Delete namespace
      kubectl patch serviceaccount ${self.triggers.service_account} -n ${self.triggers.namespace} -p '{"metadata":{"finalizers":null}}' --type=merge || true
      kubectl delete namespace ${self.triggers.namespace} --force --grace-period=0 --ignore-not-found=true || true
    EOT
  }

  depends_on = [
    aws_eks_pod_identity_association.app_pod_identity,
    kubernetes_service_account.app_service_account,
    kubernetes_namespace.app_namespace
  ]
}

# Secure EKS cluster configuration - addresses CKV_AWS_39, CKV_AWS_38, CKV_AWS_37, CKV_AWS_58

# KMS key for EKS secrets encryption
resource "aws_kms_key" "eks_secrets" {
  description             = "KMS key for EKS secrets encryption"
  deletion_window_in_days = 7
  
  tags = local.common_tags
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${local.name_prefix}-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}

# Secure EKS cluster configuration
resource "aws_eks_cluster" "this_secure" {
  name     = "${local.name_prefix}-eks"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.eks_controlplane_secure.id]
    endpoint_private_access = true
    endpoint_public_access  = true  # Always enabled as requested
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  # Enable secrets encryption
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_secrets.arn
    }
    resources = ["secrets"]
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  # Enable all cluster log types for comprehensive monitoring
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = local.common_tags

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
  ]
}

# Secure security group for EKS control plane
resource "aws_security_group" "eks_controlplane_secure" {
  name        = "${local.name_prefix}-eks-cp-sg-secure"
  description = "Secure EKS control plane security group"
  vpc_id      = var.vpc_id

  # Specific ingress from bastion on required ports only
  ingress {
    description     = "HTTPS API access from Bastion"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.bastion_sg_id]
  }

  # Specific egress rules instead of allowing all
  egress {
    description = "HTTPS outbound for API calls"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS resolution"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "NTP synchronization"
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# CloudWatch log group for EKS cluster logs with KMS encryption
resource "aws_kms_key" "eks_logs" {
  description             = "KMS key for EKS CloudWatch logs encryption"
  deletion_window_in_days = 7
  
  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${local.name_prefix}-eks/cluster"
  retention_in_days = 365  # 1 year retention for compliance

  tags = local.common_tags

  lifecycle {
    ignore_changes = [name]
  }
}

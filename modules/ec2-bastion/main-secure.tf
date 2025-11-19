# Secure EC2 Bastion Configuration
# Addresses: CKV_AWS_79, CKV_AWS_135, CKV_AWS_382, CKV_AWS_23, CKV_AWS_355, CKV_AWS_290

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Secure bastion security group
resource "aws_security_group" "bastion_sg_secure" {
  name        = "${var.project_name}-${var.env_name}-bastion-sg-secure"
  description = "Secure security group for Bastion host with restricted access"
  vpc_id      = var.vpc_id

  # SSH access from specific IPs only (replace with your office IPs)
  ingress {
    description = "SSH access from office"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs  # Define this variable
  }

  # HTTPS access for OpenVPN admin
  ingress {
    description = "HTTPS access for OpenVPN admin"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # OpenVPN admin interface
  ingress {
    description = "OpenVPN admin interface"
    from_port   = 943
    to_port     = 943
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # OpenVPN UDP
  ingress {
    description = "OpenVPN UDP"
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]  # VPN clients can come from anywhere
  }

  # Specific egress rules instead of allowing all
  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP outbound for package updates"
    from_port   = 80
    to_port     = 80
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

  # EKS API access
  egress {
    description = "EKS API access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env_name}-bastion-sg-secure"
  })
}

# Secure IAM role with least privilege
resource "aws_iam_role" "bastion_role_secure" {
  name = "${var.project_name}-${var.env_name}-bastion-role-secure"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Specific EKS access policy instead of wildcard
resource "aws_iam_role_policy" "eks_limited_access" {
  name = "${var.project_name}-${var.env_name}-eks-limited-access"
  role = aws_iam_role.bastion_role_secure.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups"
        ]
        Resource = "arn:aws:eks:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:cluster/${var.project_name}-${var.env_name}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })
}

# Instance profile
resource "aws_iam_instance_profile" "bastion_profile_secure" {
  name = "${var.project_name}-${var.env_name}-bastion-profile-secure"
  role = aws_iam_role.bastion_role_secure.name

  tags = var.tags
}

# Secure EC2 instance with hardening
resource "aws_instance" "bastion_secure" {
  ami                     = var.ami_id
  instance_type           = var.instance_type
  subnet_id               = var.public_subnet
  vpc_security_group_ids  = [aws_security_group.bastion_sg_secure.id]
  iam_instance_profile    = aws_iam_instance_profile.bastion_profile_secure.name
  key_name                = var.key_pair_name
  
  # Enable detailed monitoring
  monitoring = true
  
  # Enable EBS optimization
  ebs_optimized = true
  
  # Secure metadata service configuration (IMDSv2 only)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # Enforce IMDSv2
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Encrypted root volume
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.bastion_ebs_size
    encrypted             = true
    delete_on_termination = true
    
    tags = merge(var.tags, {
      Name = "${var.project_name}-${var.env_name}-bastion-root"
    })
  }

  # User data for security hardening
  user_data_base64 = base64encode(templatefile("${path.module}/scripts/secure_install_tools.sh", {
    project_name = var.project_name
    env_name     = var.env_name
  }))

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env_name}-bastion-secure"
  })

  lifecycle {
    prevent_destroy = false
  }
}

# Elastic IP for bastion
resource "aws_eip" "bastion_eip_secure" {
  instance = aws_instance.bastion_secure.id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env_name}-bastion-eip"
  })

  depends_on = [aws_instance.bastion_secure]
}

# Security Group
resource "aws_security_group" "bastion_sg" {
  name        = "${var.project_name}-${var.env_name}-bastion-sg"
  description = "Allow only required ports for Bastion"
  vpc_id      = var.vpc_id

  # Ingress rules
  ingress {
    description = "HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Custom TCP 943"
    from_port   = 943
    to_port     = 943
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "OpenVPN UDP 1194"
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rules (allow all outbound)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env_name}-bastion-sg"
  })
}
# IAM Role for SSM
resource "aws_iam_role" "bastion_role" {
  name = "${var.project_name}-${var.env_name}-bastion-role"

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
}

# Attach AmazonSSMManagedInstanceCore Policy
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy" "eks_full_access" {
  name = "${var.project_name}-${var.env_name}-eks-full-access"
  role = aws_iam_role.bastion_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "eks:*"
        Resource = "*"
      }
    ]
  })
}

# Instance Profile
resource "aws_iam_instance_profile" "bastion_profile" {
  name = "${var.project_name}-${var.env_name}-bastion-profile"
  role = aws_iam_role.bastion_role.name
}

resource "aws_instance" "bastion" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion_profile.name
  monitoring             = true
  #disable_api_termination = true
  #disable_api_stop        = true

  root_block_device {
    volume_type = "gp3"
    volume_size = var.bastion_ebs_size
    encrypted   = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env_name}-bastion"
  })

  lifecycle {
    prevent_destroy = false
  }

  # Install AWS CLI, kubectl, eksctl
  user_data = file("${path.module}/scripts/install_tools.sh")
}



# Allocate Elastic IP for Bastion
resource "aws_eip" "bastion_eip" {
  instance = aws_instance.bastion.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env_name}-bastion-eip"
  })
}



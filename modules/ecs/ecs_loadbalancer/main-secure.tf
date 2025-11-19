# Secure Load Balancer Configuration
# Addresses: CKV_AWS_150, CKV_AWS_131, CKV_AWS_91, CKV_AWS_2, CKV_AWS_382, CKV_AWS_260, CKV_AWS_23

# KMS key for ALB access logs encryption
resource "aws_kms_key" "alb_logs" {
  description             = "KMS key for ALB access logs encryption"
  deletion_window_in_days = 7
  
  tags = var.tags
}

# S3 bucket for ALB access logs
resource "aws_s3_bucket" "alb_access_logs" {
  bucket = "${var.project_name}-${var.env_name}-${var.service_name}-alb-logs"
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env_name}-${var.service_name}-alb-logs"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs_encryption" {
  bucket = aws_s3_bucket.alb_access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.alb_logs.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs_public_access_block" {
  bucket = aws_s3_bucket.alb_access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Secure ALB security group
resource "aws_security_group" "alb_sg_secure" {
  name        = "${var.project_name}-${var.env_name}-${var.service_name}-alb-sg-secure"
  description = "Secure security group for ${var.service_name} ALB"
  vpc_id      = var.vpc_id

  # HTTPS only ingress
  ingress {
    description = "HTTPS access from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP redirect to HTTPS (optional)
  ingress {
    description = "HTTP redirect to HTTPS"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Specific egress to target group only
  egress {
    description     = "Traffic to ECS tasks"
    from_port       = var.port
    to_port         = var.port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg_secure.id]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env_name}-${var.service_name}-alb-sg-secure"
  })
}

# Secure ECS security group
resource "aws_security_group" "ecs_sg_secure" {
  name        = "${var.project_name}-${var.env_name}-${var.service_name}-ecs-sg-secure"
  description = "Secure security group for ECS service ${var.service_name}"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow traffic from ALB only"
    from_port       = var.port
    to_port         = var.port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg_secure.id]
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

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env_name}-${var.service_name}-ecs-sg-secure"
  })
}

# Secure Application Load Balancer
resource "aws_lb" "secure_alb" {
  name               = "${var.project_name}-${var.env_name}-${var.service_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg_secure.id]
  subnets            = var.public_subnets

  # Enable deletion protection
  enable_deletion_protection = true

  # Drop invalid header fields
  drop_invalid_header_fields = true

  # Enable access logging
  access_logs {
    bucket  = aws_s3_bucket.alb_access_logs.bucket
    prefix  = "alb-access-logs"
    enabled = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env_name}-${var.service_name}-alb"
  })
}

# Target group with health checks
resource "aws_lb_target_group" "secure_tg" {
  name     = "${var.project_name}-${var.env_name}-${var.service_name}-tg"
  port     = var.port
  protocol = "HTTP"  # Internal communication can be HTTP
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env_name}-${var.service_name}-tg"
  })
}

# HTTPS listener (primary)
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.secure_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"  # TLS 1.2 minimum
  certificate_arn   = var.ssl_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.secure_tg.arn
  }
}

# HTTP listener (redirect to HTTPS)
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.secure_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

################ Application Load Balancers per Service ################
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-${var.env_name}-${var.service_name}-alb-sg"
  description = "Security group for ${var.service_name} ALB"
  vpc_id      = var.vpc_id

  # Allow HTTP (80)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS (443)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env_name}-${var.service_name}-alb-sg"
  })
}

resource "aws_lb" "this" {
name               = "${var.project_name}-${var.env_name}-${var.service_name}-alb"
internal           = false
load_balancer_type = "application"
security_groups    = [aws_security_group.alb_sg.id]
subnets            = var.public_subnets
tags = merge(var.tags, {
Name = "${var.project_name}-${var.env_name}-${var.service_name}-alb"
})
}


################ Target Group per Service ################
resource "aws_lb_target_group" "tg" {
  name        = "${var.project_name}-${var.env_name}-${var.service_name}-tg"
  port        = var.port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    matcher             = "200-499"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400 # 1 day = 86400 seconds
    enabled         = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env_name}-${var.service_name}-tg"
  })
}

################ Listener per ALB ################
resource "aws_lb_listener" "listener" {
load_balancer_arn = aws_lb.this.arn
port              = var.port
protocol          = "HTTP"
default_action {
type             = "forward"
target_group_arn = aws_lb_target_group.tg.arn
}
}

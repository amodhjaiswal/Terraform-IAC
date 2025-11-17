#############################################
# CloudWatch Log Group per Service
#############################################
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/${var.project_name}-${var.env_name}/${var.service_name}/ecs"
  retention_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env_name}-${var.service_name}-logs"
  })
}

#############################################
# ECS Service Security Group
#############################################
resource "aws_security_group" "ecs_sg" {
  name        = "${var.project_name}-${var.env_name}-${var.service_name}-ecs-sg"
  description = "Security group for ECS service ${var.service_name}"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow traffic from ALB"
    from_port       = var.port
    to_port         = var.port
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env_name}-${var.service_name}-ecs-sg"
  })
}

#############################################
# ECS Task Definition
#############################################
resource "aws_ecs_task_definition" "task_def" {
  family                   = "${var.project_name}-${var.env_name}-${var.service_name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  ephemeral_storage {
    size_in_gib = 25
  }

  container_definitions = jsonencode([
    {
      name      = var.service_name
      image     = "${var.ecr_repository_url}:${var.service_name}-latest"
      essential = true

      portMappings = [
        {
          containerPort = tonumber(var.port)
          hostPort      = tonumber(var.port)
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = var.service_name
        }
      }

      mountPoints = [
        {
          sourceVolume  = "${var.project_name}-${var.env_name}-ecs"
          containerPath = "/mnt/app"
          readOnly      = false
        }
      ]
    }
  ])

  volume {
    name = "${var.project_name}-${var.env_name}-ecs"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env_name}-${var.service_name}-task"
  })
}

#############################################
# ECS Service
#############################################
resource "aws_ecs_service" "service" {
  name            = "${var.project_name}-${var.env_name}-${var.service_name}-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.task_def.arn
  #task_definition = "${aws_ecs_task_definition.task_def.family}:latest"          
  desired_count   = var.ecs_task_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.service_name  
    container_port   = var.port
  }

  depends_on = [
    aws_ecs_task_definition.task_def,
    aws_cloudwatch_log_group.ecs_logs
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env_name}-${var.service_name}-service"
  })
}

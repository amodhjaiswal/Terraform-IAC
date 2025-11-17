# Security Group
resource "aws_security_group" "redis_sg" {
  name        = "${var.project_name}-${var.env_name}-redis-sg"
  description = "Security group for Redis"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow Redis access from VPC CIDR"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# Parameter Group
resource "aws_elasticache_parameter_group" "redis_param_group" {
  name        = "${var.project_name}-${var.env_name}-redis-param-group"
  family      = "redis${var.engine_version_major}"
  description = "Custom Redis parameter group"

  parameter {
    name  = "slowlog-log-slower-than"
    value = "10000"
  }

  tags = var.tags
}

# Subnet Group
resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name        = "${var.project_name}-${var.env_name}-redis-subnet-group"
  subnet_ids  = var.private_subnet_ids
  description = "Subnet group for Redis"

  tags = var.tags
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "redis_slowlog" {
  name              = "${var.project_name}-${var.env_name}-redis-slowlog"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "redis_enginelog" {
  name              = "${var.project_name}-${var.env_name}-redis-enginelog"
  retention_in_days = 14
  tags              = var.tags
}

# Redis Replication Group
resource "aws_elasticache_replication_group" "redis_cluster" {
  replication_group_id       = "${var.project_name}-${var.env_name}-redis"
  description                = "Redis replication group (2 nodes, cluster mode disabled)"
  engine                     = "redis"
  engine_version             = var.engine_version
  node_type                  = var.node_type
  replicas_per_node_group    = 1
  automatic_failover_enabled = var.multi_az
  multi_az_enabled           = var.multi_az
  parameter_group_name       = aws_elasticache_parameter_group.redis_param_group.name
  subnet_group_name          = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids         = [aws_security_group.redis_sg.id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  apply_immediately          = true
  cluster_mode               = "disabled"
  snapshot_retention_limit   = 7
  snapshot_window            = "05:00-06:00"

  log_delivery_configuration {
    destination_type = "cloudwatch-logs"
    destination      = aws_cloudwatch_log_group.redis_slowlog.name
    log_format       = "json"
    log_type         = "slow-log"
  }

  log_delivery_configuration {
    destination_type = "cloudwatch-logs"
    destination      = aws_cloudwatch_log_group.redis_enginelog.name
    log_format       = "json"
    log_type         = "engine-log"
  }

  tags = var.tags
}
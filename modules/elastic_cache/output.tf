output "redis_endpoint" {
  value = aws_elasticache_replication_group.redis_cluster.primary_endpoint_address
}

output "redis_port" {
  value = 6379
}

output "redis_security_group_id" {
  value = aws_security_group.redis_sg.id
}

output "redis_parameter_group_name" {
  value = aws_elasticache_parameter_group.redis_param_group.name
}

output "redis_subnet_group_name" {
  value = aws_elasticache_subnet_group.redis_subnet_group.name
}

output "redis_slowlog_cloudwatch_group" {
  value = aws_cloudwatch_log_group.redis_slowlog.name
}

output "redis_enginelog_cloudwatch_group" {
  value = aws_cloudwatch_log_group.redis_enginelog.name
}

locals {
  name_prefix  = "${var.project_name}-${var.env_name}"
  common_tags  = merge({
    Name        = local.name_prefix
    Project     = var.project_name
    Environment = var.env_name
  }, var.tags)
}

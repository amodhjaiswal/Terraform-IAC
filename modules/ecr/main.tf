################ ECR Repository ################
resource "aws_ecr_repository" "this" {
  name = "${var.project_name}-${var.env_name}-ecr"

  image_scanning_configuration {
    scan_on_push = true
  }

  image_tag_mutability = "MUTABLE" 

  force_delete = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env_name}-ecr"
  })
}

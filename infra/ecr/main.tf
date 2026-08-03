resource "aws_ecr_repository" "service" {
  for_each = var.services

  name                 = "${var.repository_prefix}/${each.value}"
  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Service = each.value
  }
}

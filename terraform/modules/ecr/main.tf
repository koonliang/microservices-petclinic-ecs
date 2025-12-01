locals {
  services = [
    "config-server",
    "api-gateway",
    "customers-service",
    "visits-service",
    "vets-service",
  ]
}

resource "aws_ecr_repository" "services" {
  for_each             = toset(var.services)
  name                 = "petclinic/${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false # Disable to reduce costs
  }
}

# Keep only 2 images to stay within 500MB free tier
resource "aws_ecr_lifecycle_policy" "cleanup" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only last 2 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 2
      }
      action = { type = "expire" }
    }]
  })
}

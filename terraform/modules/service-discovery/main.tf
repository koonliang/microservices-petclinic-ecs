resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "petclinic.local"
  description = "Private DNS namespace for PetClinic"
  vpc         = var.vpc_id

  tags = {
    Name = "${var.project}-${var.environment}-namespace"
  }
}

resource "aws_service_discovery_service" "services" {
  for_each = toset(var.service_names)

  name = each.key

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"  # A record - works with awsvpc network mode
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

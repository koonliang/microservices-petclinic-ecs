output "namespace_id" {
  value = aws_service_discovery_private_dns_namespace.main.id
}

output "service_arns" {
  value = { for k, v in aws_service_discovery_service.services : k => v.arn }
}

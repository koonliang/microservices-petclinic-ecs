output "application_url" {
  description = "Application URL"
  value       = "http://${module.alb.dns_name}"
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.dns_name
}

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = data.terraform_remote_state.ecr.outputs.repository_urls
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs_cluster.cluster_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = var.enable_rds ? module.rds.rds_endpoint : "RDS disabled"
}

output "service_discovery_namespace" {
  description = "Service discovery namespace"
  value       = "petclinic.local"
}

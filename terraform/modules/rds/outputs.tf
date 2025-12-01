output "rds_endpoint" {
  value = var.enable_rds ? aws_db_instance.main[0].endpoint : ""
}

output "db_secret_arn" {
  value = var.enable_rds ? aws_secretsmanager_secret.db_credentials[0].arn : ""
}

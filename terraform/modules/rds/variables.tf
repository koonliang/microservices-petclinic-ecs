variable "enable_rds" {
  type    = bool
  default = false
}

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Subnet IDs for RDS (private for SIT/PROD, can be public for DEV)"
  type        = list(string)
}

variable "ecs_security_group_id" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

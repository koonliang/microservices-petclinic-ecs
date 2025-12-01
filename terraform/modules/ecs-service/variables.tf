variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "service_name" {
  type = string
}

variable "cluster_id" {
  type = string
}

variable "execution_role_arn" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "ecr_repository_url" {
  type = string
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "cpu" {
  type    = number
  default = 128
}

variable "memory_reservation" {
  type    = number
  default = 200
}

variable "container_port" {
  type = number
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "enable_alb" {
  type    = bool
  default = false
}

variable "target_group_arn" {
  type    = string
  default = ""
}

variable "enable_rds" {
  type    = bool
  default = false
}

variable "rds_endpoint" {
  type    = string
  default = ""
}

variable "db_secret_arn" {
  type    = string
  default = ""
}

variable "additional_env_vars" {
  type    = list(map(string))
  default = []
}

#############################
# Service Discovery (for SIT/PROD)
#############################

variable "enable_service_discovery" {
  description = "Enable Cloud Map service discovery (for multi-EC2 environments)"
  type        = bool
  default     = false
}

variable "service_discovery_arn" {
  description = "Cloud Map service ARN"
  type        = string
  default     = ""
}

variable "discovery_namespace" {
  description = "Service discovery namespace (e.g., petclinic.local)"
  type        = string
  default     = "petclinic.local"
}

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

#############################
# Network (for awsvpc mode)
#############################

variable "subnet_ids" {
  description = "Subnet IDs for awsvpc network mode"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "assign_public_ip" {
  description = "Assign public IP to ECS tasks (required for public subnets without NAT)"
  type        = bool
  default     = false
}

#############################
# ECS Service Auto Scaling
#############################

variable "enable_autoscaling" {
  description = "Enable ECS service auto scaling"
  type        = bool
  default     = false
}

variable "cluster_name" {
  description = "ECS cluster name (required for autoscaling resource_id)"
  type        = string
  default     = ""
}

variable "min_task_count" {
  description = "Minimum number of tasks for autoscaling"
  type        = number
  default     = 1
}

variable "max_task_count" {
  description = "Maximum number of tasks for autoscaling"
  type        = number
  default     = 2
}

variable "autoscaling_cpu_target" {
  description = "Target CPU utilization percentage for autoscaling"
  type        = number
  default     = 70
}

variable "autoscaling_memory_target" {
  description = "Target memory utilization percentage for autoscaling"
  type        = number
  default     = 70
}

variable "scale_in_cooldown" {
  description = "Cooldown period in seconds before scaling in"
  type        = number
  default     = 300
}

variable "scale_out_cooldown" {
  description = "Cooldown period in seconds before scaling out"
  type        = number
  default     = 60
}

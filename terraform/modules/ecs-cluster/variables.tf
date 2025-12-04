variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS instances"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ECS instances (used when use_public_subnets = true)"
  type        = list(string)
  default     = []
}

variable "use_public_subnets" {
  description = "Deploy ECS instances in public subnets with public IPs (for dev - no NAT/VPC endpoints needed)"
  type        = bool
  default     = false
}

variable "ecs_security_group_id" {
  type = string
}

variable "enable_rds" {
  type    = bool
  default = false
}

#############################
# Auto Scaling Group Size
#############################

variable "min_size" {
  description = "Minimum number of EC2 instances"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of EC2 instances"
  type        = number
  default     = 1
}

variable "desired_capacity" {
  description = "Desired number of EC2 instances"
  type        = number
  default     = 1
}

#############################
# Capacity Provider Scaling
#############################

variable "enable_capacity_provider_scaling" {
  description = "Enable ECS Capacity Provider managed scaling for EC2 instances"
  type        = bool
  default     = false
}

variable "capacity_provider_target" {
  description = "Target capacity percentage for capacity provider scaling"
  type        = number
  default     = 100
}

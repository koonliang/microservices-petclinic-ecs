variable "project" {
  description = "Project name"
  type        = string
  default     = "petclinic"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "sit"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.1.0.0/16"  # Different from DEV
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "instance_type" {
  description = "EC2 instance type for ECS"
  type        = string
  default     = "t2.micro"
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

#############################
# EC2 Auto Scaling
#############################

variable "ec2_min_size" {
  description = "Minimum number of EC2 instances"
  type        = number
  default     = 5  # One per service
}

variable "ec2_max_size" {
  description = "Maximum number of EC2 instances"
  type        = number
  default     = 5
}

variable "ec2_desired_capacity" {
  description = "Desired number of EC2 instances"
  type        = number
  default     = 5
}

#############################
# Auto Scaling
#############################

variable "enable_capacity_provider_scaling" {
  description = "Enable ECS Capacity Provider managed scaling for EC2 instances"
  type        = bool
  default     = true
}

variable "enable_autoscaling" {
  description = "Enable ECS service task-level auto scaling (CPU/memory based)"
  type        = bool
  default     = false
}

variable "max_task_count" {
  description = "Maximum number of tasks per service for autoscaling"
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

#############################
# RDS
#############################

variable "enable_rds" {
  description = "Enable RDS MySQL"
  type        = bool
  default     = true  # SIT uses real database
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

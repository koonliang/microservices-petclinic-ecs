variable "project" {
  description = "Project name"
  type        = string
  default     = "petclinic"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
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
# RDS (Optional)
#############################

variable "enable_rds" {
  description = "Enable RDS MySQL (default: false, uses in-memory HSQLDB)"
  type        = bool
  default     = false
}

variable "db_password" {
  description = "Database password (required if enable_rds = true)"
  type        = string
  sensitive   = true
  default     = ""
}

#############################
# Service Discovery
#############################

variable "enable_service_discovery" {
  description = "Enable Cloud Map service discovery (for multi-EC2 environments like SIT/PROD)"
  type        = bool
  default     = false  # DEV uses localhost
}

#############################
# EC2 Auto Scaling
#############################

variable "ec2_min_size" {
  description = "Minimum number of EC2 instances"
  type        = number
  default     = 1
}

variable "ec2_max_size" {
  description = "Maximum number of EC2 instances"
  type        = number
  default     = 1
}

variable "ec2_desired_capacity" {
  description = "Desired number of EC2 instances"
  type        = number
  default     = 1
}

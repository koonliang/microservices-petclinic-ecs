variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type = list(string)
}

#############################
# Cost Optimization Options
#############################

variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for AWS services (expensive ~$130/day). Set false to use NAT or public subnets instead."
  type        = bool
  default     = false
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnet internet access (~$1/day + data transfer)"
  type        = bool
  default     = false
}

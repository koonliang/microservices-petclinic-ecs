terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

locals {
  services = {
    "config-server" = {
      cpu                = 256
      memory_reservation = 384
      port               = 8888
      desired_count      = 1
      enable_alb         = false
    }
    "api-gateway" = {
      cpu                = 256
      memory_reservation = 384
      port               = 8080
      desired_count      = 1
      enable_alb         = true
    }
    "customers-service" = {
      cpu                = 256
      memory_reservation = 300
      port               = 8081
      desired_count      = 1
      enable_alb         = false
    }
    "visits-service" = {
      cpu                = 256
      memory_reservation = 300
      port               = 8082
      desired_count      = 1
      enable_alb         = false
    }
    "vets-service" = {
      cpu                = 256
      memory_reservation = 300
      port               = 8083
      desired_count      = 1
      enable_alb         = false
    }
  }
}

#############################
# Networking
#############################
module "networking" {
  source = "../../modules/networking"

  project            = var.project
  environment        = var.environment
  aws_region         = var.aws_region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  # Cost optimization: No VPC endpoints, no NAT - use public subnets for ECS
  enable_vpc_endpoints = false
  enable_nat_gateway   = false
}

#############################
# ECR Repositories (from shared state)
#############################
data "terraform_remote_state" "ecr" {
  backend = "s3"
  config = {
    bucket = "petclinic-tfstate-309779120361"
    key    = "shared/ecr/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

#############################
# Service Discovery (enabled for multi-EC2)
#############################
module "service_discovery" {
  source = "../../modules/service-discovery"

  project       = var.project
  environment   = var.environment
  vpc_id        = module.networking.vpc_id
  service_names = keys(local.services)
}

#############################
# ECS Cluster
#############################
module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  project               = var.project
  environment           = var.environment
  aws_region            = var.aws_region
  instance_type         = var.instance_type
  private_subnet_ids    = module.networking.private_subnet_ids
  public_subnet_ids     = module.networking.public_subnet_ids
  use_public_subnets    = true  # DEV: Use public subnets to avoid VPC endpoint costs
  ecs_security_group_id = module.networking.ecs_security_group_id
  enable_rds            = var.enable_rds

  # EC2 Auto Scaling
  min_size         = var.ec2_min_size
  max_size         = var.ec2_max_size
  desired_capacity = var.ec2_desired_capacity
}

#############################
# ALB
#############################
module "alb" {
  source = "../../modules/alb"

  project               = var.project
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.networking.alb_security_group_id
}

#############################
# RDS (Optional)
#############################
module "rds" {
  source = "../../modules/rds"

  enable_rds            = var.enable_rds
  project               = var.project
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  ecs_security_group_id = module.networking.ecs_security_group_id
  db_password           = var.db_password
}

#############################
# ECS Services
#############################
module "ecs_services" {
  source   = "../../modules/ecs-service"
  for_each = local.services

  project      = var.project
  environment  = var.environment
  service_name = each.key
  aws_region   = var.aws_region

  cluster_id         = module.ecs_cluster.cluster_id
  execution_role_arn = module.ecs_cluster.execution_role_arn
  task_role_arn      = module.ecs_cluster.task_role_arn

  ecr_repository_url = data.terraform_remote_state.ecr.outputs.repository_urls[each.key]
  image_tag          = var.image_tag

  cpu                = each.value.cpu
  memory_reservation = each.value.memory_reservation
  container_port     = each.value.port
  desired_count      = each.value.desired_count

  # Network configuration for awsvpc mode (use public subnets for DEV)
  subnet_ids        = module.networking.public_subnet_ids
  security_group_id = module.networking.ecs_security_group_id

  # ALB (only for api-gateway)
  enable_alb       = each.value.enable_alb
  target_group_arn = module.alb.target_group_arn

  # Service Discovery
  enable_service_discovery = var.enable_service_discovery
  service_discovery_arn    = module.service_discovery.service_arns[each.key]
  discovery_namespace      = "petclinic.local"

  # RDS (optional)
  enable_rds    = var.enable_rds
  rds_endpoint  = module.rds.rds_endpoint
  db_secret_arn = module.rds.db_secret_arn

  additional_env_vars = []
}

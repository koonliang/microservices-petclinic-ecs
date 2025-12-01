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
      cpu                = 128
      memory_reservation = 200
      port               = 8888
      desired_count      = 1
      enable_alb         = false
    }
    "api-gateway" = {
      cpu                = 128
      memory_reservation = 200
      port               = 8080
      desired_count      = 1
      enable_alb         = true
    }
    "customers-service" = {
      cpu                = 128
      memory_reservation = 150
      port               = 8081
      desired_count      = 1
      enable_alb         = false
    }
    "visits-service" = {
      cpu                = 128
      memory_reservation = 150
      port               = 8082
      desired_count      = 1
      enable_alb         = false
    }
    "vets-service" = {
      cpu                = 128
      memory_reservation = 150
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
}

#############################
# ECR Repositories
#############################
module "ecr" {
  source = "../../modules/ecr"

  project  = var.project
  services = keys(local.services)
}

#############################
# Service Discovery (only if enabled)
#############################
module "service_discovery" {
  count  = var.enable_service_discovery ? 1 : 0
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
  ecs_security_group_id = module.networking.ecs_security_group_id
  enable_rds            = var.enable_rds
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

  ecr_repository_url = module.ecr.repository_urls[each.key]
  image_tag          = var.image_tag

  cpu                = each.value.cpu
  memory_reservation = each.value.memory_reservation
  container_port     = each.value.port
  desired_count      = each.value.desired_count

  # ALB (only for api-gateway)
  enable_alb       = each.value.enable_alb
  target_group_arn = module.alb.target_group_arn

  # Service Discovery (disabled for DEV - uses localhost)
  enable_service_discovery = var.enable_service_discovery
  service_discovery_arn    = var.enable_service_discovery ? module.service_discovery[0].service_arns[each.key] : ""
  discovery_namespace      = "petclinic.local"

  # RDS (optional)
  enable_rds    = var.enable_rds
  rds_endpoint  = module.rds.rds_endpoint
  db_secret_arn = module.rds.db_secret_arn

  additional_env_vars = []
}

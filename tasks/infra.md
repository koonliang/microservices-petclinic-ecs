# ECS Deployment Infrastructure Plan for Spring PetClinic Microservices

## Executive Summary

This document outlines the Terraform-based infrastructure plan for deploying the Spring PetClinic microservices application to AWS ECS (Elastic Container Service). The architecture uses **private subnets with VPC Endpoints** for near-zero cost while maintaining security best practices.

**Cost Optimization Strategy:**
- ECS on EC2 (t2.micro - Free Tier eligible)
- **Private subnets with VPC Endpoints** (no NAT Gateway - ~$0.01/GB data only)
- Optional RDS MySQL (disabled by default, uses in-memory HSQLDB)
- Minimal CloudWatch logging retention

---

## 1. Current Architecture Analysis

### 1.1 Microservices Inventory

| Service | Port | Dependencies | Purpose |
|---------|------|--------------|---------|
| config-server | 8888 | None | Centralized configuration management |
| discovery-server | 8761 | config-server | Service registry (Eureka) |
| api-gateway | 8080 | config-server, discovery-server | API routing and load balancing |
| customers-service | 8081 | config-server, discovery-server | Customer/Pet management |
| visits-service | 8082 | config-server, discovery-server | Visit scheduling |
| vets-service | 8083 | config-server, discovery-server | Veterinarian management |
| admin-server | 9090 | config-server, discovery-server | Spring Boot Admin dashboard |

### 1.2 Key Observations

- All services use Spring Cloud Config for externalized configuration
- Eureka handles service discovery (replaced by AWS Cloud Map in ECS)
- Services expose Actuator endpoints for health checks
- Memory allocation: 512MB per service (optimized for t2.micro)
- Base image: Eclipse Temurin Java 17
- **Default database: In-memory HSQLDB** (no external DB required)

---

## 2. Target AWS Architecture

### 2.1 Architecture Decisions

| Component | Choice | Reason |
|-----------|--------|--------|
| ECS Launch Type | EC2 (t2.micro) | Free tier eligible |
| Subnets | **Private** | Security best practice |
| Internet Access | **VPC Endpoints** | No hourly cost, pay per GB (~$0.01/GB) |
| Service Discovery | AWS Cloud Map | Native ECS integration |
| Load Balancer | ALB | 750 hrs/month free |
| Database | HSQLDB (default) | No RDS cost, optional MySQL |
| Container Registry | ECR | 500MB free storage |

### 2.2 VPC Endpoints vs NAT Gateway

| Approach | Hourly Cost | Data Cost | 8-hr Test |
|----------|-------------|-----------|-----------|
| **VPC Endpoints** | **$0** | **$0.01/GB** | **~$0.01** |
| NAT Gateway | $0.045/hr | $0.045/GB | ~$0.40 |
| NAT Instance | $0 (free tier) | $0 | $0 but complex |

**VPC Endpoints win for quick test/tear-down scenarios.**


### 2.3 Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                                    AWS Cloud                                          │
│  ┌────────────────────────────────────────────────────────────────────────────────┐  │
│  │                              VPC (10.0.0.0/16)                                  │  │
│  │                                                                                 │  │
│  │   ┌─────────────────────────────┐    ┌─────────────────────────────────────┐   │  │
│  │   │      Public Subnets         │    │         Private Subnets             │   │  │
│  │   │      (10.0.1.0/24,          │    │         (10.0.11.0/24,              │   │  │
│  │   │       10.0.2.0/24)          │    │          10.0.12.0/24)              │   │  │
│  │   │                             │    │                                     │   │  │
│  │   │   ┌───────────────────┐     │    │    ┌────────────────────────────┐   │   │  │
│  │   │   │        ALB        │     │    │    │    EC2 t2.micro (ECS)     │   │   │  │
│  │   │   │   (Internet-      │─────┼────┼───►│  ┌──────────────────────┐ │   │   │  │
│  │   │   │    facing)        │     │    │    │  │    api-gateway       │ │   │   │  │
│  │   │   └───────────────────┘     │    │    │  ├──────────────────────┤ │   │   │  │
│  │   │            ▲                │    │    │  │   config-server      │ │   │   │  │
│  │   │            │                │    │    │  ├──────────────────────┤ │   │   │  │
│  │   └────────────┼────────────────┘    │    │  │  customers-service   │ │   │   │  │
│  │                │                      │    │  ├──────────────────────┤ │   │   │  │
│  │         Internet Gateway              │    │  │   visits-service     │ │   │   │  │
│  │                │                      │    │  ├──────────────────────┤ │   │   │  │
│  │                ▼                      │    │  │    vets-service      │ │   │   │  │
│  │           Internet                    │    │  └──────────────────────┘ │   │   │  │
│  │                                       │    └─────────────┬──────────────┘   │   │  │
│  │                                       │                  │                   │   │  │
│  │                                       │                  ▼                   │   │  │
│  │   ┌───────────────────────────────────┼──────────────────────────────────┐   │   │  │
│  │   │                        VPC Endpoints                                 │   │   │  │
│  │   │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐        │   │   │  │
│  │   │  │   S3    │ │ECR.api  │ │ECR.dkr  │ │   ECS   │ │  Logs   │        │   │   │  │
│  │   │  │(Gateway)│ │         │ │         │ │ agent   │ │         │        │   │   │  │
│  │   │  │  FREE   │ │$0.01/GB │ │$0.01/GB │ │$0.01/GB │ │$0.01/GB │        │   │   │  │
│  │   │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘        │   │   │  │
│  │   └──────────────────────────────────────────────────────────────────────┘   │   │  │
│  │                                       │                                      │   │  │
│  │                                       │    ┌──────────────────────────┐      │   │  │
│  │                                       │    │     AWS Cloud Map        │      │   │  │
│  │                                       │    │   (Service Discovery)    │      │   │  │
│  │                                       │    └──────────────────────────┘      │   │  │
│  │                                       │                                      │   │  │
│  │                                       │    ┌──────────────────────────┐      │   │  │
│  │                                       │    │   RDS MySQL (OPTIONAL)   │      │   │  │
│  │                                       │    │   enable_rds = false     │      │   │  │
│  │                                       │    └──────────────────────────┘      │   │  │
│  │                                       │                                      │   │  │
│  │                                       └──────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                        │
│  ┌─────────────────────────┐  ┌─────────────────────────────────────────────────────┐  │
│  │          ECR            │  │              CloudWatch Logs                        │  │
│  │    (500MB free)         │  │            (5GB free ingestion)                     │  │
│  └─────────────────────────┘  └─────────────────────────────────────────────────────┘  │
│                                                                                        │
└────────────────────────────────────────────────────────────────────────────────────────┘
```


---

## 3. Terraform Module Structure

```
terraform/
├── environments/
│   └── dev/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── terraform.tfvars
│       └── backend.tf
│
├── modules/
│   ├── networking/
│   │   ├── main.tf           # VPC, subnets
│   │   ├── endpoints.tf      # VPC Endpoints
│   │   ├── security-groups.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── ecs-cluster/
│   │   ├── main.tf
│   │   ├── ec2-launch-template.tf
│   │   ├── iam.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── ecs-service/
│   │   ├── main.tf
│   │   ├── task-definition.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── alb/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── ecr/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── service-discovery/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── rds/                   # OPTIONAL MODULE
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
└── shared/
    └── backend.tf
```

---

## 4. Infrastructure Components

### 4.1 Networking Module with VPC Endpoints

```hcl
# modules/networking/main.tf

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "${var.project}-${var.environment}-vpc"
  }
}

#############################
# Public Subnets (for ALB only)
#############################

resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${var.project}-${var.environment}-public-${count.index + 1}"
    Type = "public"
  }
}

#############################
# Private Subnets (for ECS)
#############################

resource "aws_subnet" "private" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false
  
  tags = {
    Name = "${var.project}-${var.environment}-private-${count.index + 1}"
    Type = "private"
  }
}

#############################
# Internet Gateway (for ALB)
#############################

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "${var.project}-${var.environment}-igw"
  }
}

#############################
# Route Tables
#############################

# Public route table (routes to IGW)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name = "${var.project}-${var.environment}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route table (no internet route - uses VPC endpoints)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "${var.project}-${var.environment}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
```


### 4.2 VPC Endpoints (Key for Private Subnets)

```hcl
# modules/networking/endpoints.tf

#############################
# Security Group for VPC Endpoints
#############################

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project}-${var.environment}-vpce-sg"
  description = "Security group for VPC Endpoints"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.project}-${var.environment}-vpce-sg"
  }
}

#############################
# S3 Gateway Endpoint (FREE)
#############################

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  
  tags = {
    Name = "${var.project}-${var.environment}-s3-endpoint"
  }
}

#############################
# Interface Endpoints ($0.01/GB)
#############################

locals {
  interface_endpoints = [
    "ecr.api",      # ECR API calls
    "ecr.dkr",      # Docker image pulls
    "ecs",          # ECS service API
    "ecs-agent",    # ECS agent communication
    "ecs-telemetry", # ECS telemetry
    "logs",         # CloudWatch Logs
  ]
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(local.interface_endpoints)
  
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  
  tags = {
    Name = "${var.project}-${var.environment}-${each.key}-endpoint"
  }
}
```

### 4.3 Security Groups

```hcl
# modules/networking/security-groups.tf

#############################
# ALB Security Group
#############################

resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.environment}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.project}-${var.environment}-alb-sg"
  }
}

#############################
# ECS Instances Security Group
#############################

resource "aws_security_group" "ecs" {
  name        = "${var.project}-${var.environment}-ecs-sg"
  description = "Security group for ECS instances"
  vpc_id      = aws_vpc.main.id
  
  # Allow traffic from ALB on dynamic port range
  ingress {
    description     = "Traffic from ALB"
    from_port       = 32768
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  
  # Allow inter-container communication
  ingress {
    description = "Inter-container traffic"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }
  
  # Egress to VPC endpoints (HTTPS)
  egress {
    description     = "HTTPS to VPC Endpoints"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.vpc_endpoints.id]
  }
  
  # Egress to S3 (via gateway endpoint)
  egress {
    description     = "S3 via Gateway Endpoint"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [aws_vpc_endpoint.s3.prefix_list_id]
  }
  
  # Allow internal communication within VPC
  egress {
    description = "Internal VPC traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }
  
  tags = {
    Name = "${var.project}-${var.environment}-ecs-sg"
  }
}
```


### 4.4 ECR Module

```hcl
# modules/ecr/main.tf

locals {
  services = [
    "config-server",
    "api-gateway",
    "customers-service",
    "visits-service",
    "vets-service",
  ]
}

resource "aws_ecr_repository" "services" {
  for_each             = toset(local.services)
  name                 = "petclinic/${each.key}"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = false  # Disable to reduce costs
  }
}

# Keep only 2 images to stay within 500MB free tier
resource "aws_ecr_lifecycle_policy" "cleanup" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name
  
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only last 2 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 2
      }
      action = { type = "expire" }
    }]
  })
}

output "repository_urls" {
  value = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}
```

### 4.5 ECS Cluster with EC2 (Free Tier)

```hcl
# modules/ecs-cluster/main.tf

resource "aws_ecs_cluster" "main" {
  name = "${var.project}-${var.environment}"
  
  setting {
    name  = "containerInsights"
    value = "disabled"  # Disable to reduce costs
  }
  
  tags = {
    Name = "${var.project}-${var.environment}-cluster"
  }
}

#############################
# ECS-optimized AMI
#############################

data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

#############################
# Launch Template
#############################

resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.project}-${var.environment}-ecs-"
  image_id      = data.aws_ami.ecs_optimized.id
  instance_type = var.instance_type
  
  iam_instance_profile {
    name = aws_iam_instance_profile.ecs.name
  }
  
  # NO public IP - private subnet with VPC endpoints
  network_interfaces {
    associate_public_ip_address = false
    security_groups            = [var.ecs_security_group_id]
  }
  
  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config
    echo "ECS_ENABLE_CONTAINER_METADATA=true" >> /etc/ecs/ecs.config
  EOF
  )
  
  monitoring {
    enabled = false  # Disable detailed monitoring to reduce costs
  }
  
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project}-${var.environment}-ecs-instance"
    }
  }
}

#############################
# Auto Scaling Group
#############################

resource "aws_autoscaling_group" "ecs" {
  name                = "${var.project}-${var.environment}-ecs-asg"
  vpc_zone_identifier = var.private_subnet_ids  # Private subnets
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  
  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }
  
  tag {
    key                 = "Name"
    value               = "${var.project}-${var.environment}-ecs-instance"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}

#############################
# Capacity Provider
#############################

resource "aws_ecs_capacity_provider" "ec2" {
  name = "${var.project}-${var.environment}-ec2"
  
  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn
    
    managed_scaling {
      status          = "DISABLED"
      target_capacity = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.ec2.name]
  
  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2.name
    weight            = 100
    base              = 1
  }
}
```


### 4.6 IAM Roles for ECS

```hcl
# modules/ecs-cluster/iam.tf

#############################
# ECS Instance Role
#############################

resource "aws_iam_role" "ecs_instance" {
  name = "${var.project}-${var.environment}-ecs-instance-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs" {
  name = "${var.project}-${var.environment}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance.name
}

#############################
# ECS Task Execution Role
#############################

resource "aws_iam_role" "ecs_execution" {
  name = "${var.project}-${var.environment}-ecs-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for Secrets Manager (if RDS enabled)
resource "aws_iam_role_policy" "ecs_execution_secrets" {
  count = var.enable_rds ? 1 : 0
  name  = "secrets-access"
  role  = aws_iam_role.ecs_execution.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = ["arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.project}/*"]
    }]
  })
}

#############################
# ECS Task Role
#############################

resource "aws_iam_role" "ecs_task" {
  name = "${var.project}-${var.environment}-ecs-task-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}
```

### 4.7 Service Discovery (AWS Cloud Map)

```hcl
# modules/service-discovery/main.tf

resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "petclinic.local"
  description = "Private DNS namespace for PetClinic"
  vpc         = var.vpc_id
  
  tags = {
    Name = "${var.project}-${var.environment}-namespace"
  }
}

resource "aws_service_discovery_service" "services" {
  for_each = toset(var.service_names)
  
  name = each.key
  
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    
    dns_records {
      ttl  = 10
      type = "A"
    }
    
    routing_policy = "MULTIVALUE"
  }
  
  health_check_custom_config {
    failure_threshold = 1
  }
}

output "namespace_id" {
  value = aws_service_discovery_private_dns_namespace.main.id
}

output "service_arns" {
  value = { for k, v in aws_service_discovery_service.services : k => v.arn }
}
```


### 4.8 ECS Service Module

```hcl
# modules/ecs-service/main.tf

resource "aws_ecs_task_definition" "service" {
  family                   = "${var.project}-${var.service_name}"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.execution_role_arn
  task_role_arn           = var.task_role_arn
  
  container_definitions = jsonencode([{
    name  = var.service_name
    image = "${var.ecr_repository_url}:${var.image_tag}"
    
    portMappings = [{
      containerPort = var.container_port
      hostPort      = var.enable_alb ? 0 : var.container_port
      protocol      = "tcp"
    }]
    
    environment = concat([
      {
        name  = "SPRING_PROFILES_ACTIVE"
        value = var.enable_rds ? "docker,aws,mysql" : "docker,aws"
      },
      {
        name  = "CONFIG_SERVER_URL"
        value = "http://config-server.petclinic.local:8888"
      },
      {
        name  = "EUREKA_CLIENT_ENABLED"
        value = "false"
      }
    ], var.enable_rds && var.rds_endpoint != "" ? [
      {
        name  = "SPRING_DATASOURCE_URL"
        value = "jdbc:mysql://${var.rds_endpoint}:3306/petclinic"
      }
    ] : [], var.additional_env_vars)
    
    secrets = var.enable_rds && var.db_secret_arn != "" ? [
      {
        name      = "SPRING_DATASOURCE_USERNAME"
        valueFrom = "${var.db_secret_arn}:username::"
      },
      {
        name      = "SPRING_DATASOURCE_PASSWORD"
        valueFrom = "${var.db_secret_arn}:password::"
      }
    ] : []
    
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/actuator/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 120
    }
    
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.project}/${var.service_name}"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
    
    cpu               = var.cpu
    memoryReservation = var.memory_reservation
  }])
}

resource "aws_ecs_service" "service" {
  name            = var.service_name
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = var.desired_count
  launch_type     = "EC2"
  
  dynamic "service_registries" {
    for_each = var.enable_service_discovery ? [1] : []
    content {
      registry_arn = var.service_discovery_arn
    }
  }
  
  dynamic "load_balancer" {
    for_each = var.enable_alb ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.service_name
      container_port   = var.container_port
    }
  }
  
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  
  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }
}

resource "aws_cloudwatch_log_group" "service" {
  name              = "/ecs/${var.project}/${var.service_name}"
  retention_in_days = 3  # Minimal retention
}
```

### 4.9 Service Configuration (Memory for t2.micro)

**t2.micro: 1GB RAM, ~900MB available after ECS agent**

| Service | CPU Units | Memory Reservation | Port | ALB |
|---------|-----------|-------------------|------|-----|
| config-server | 128 | 200 MB | 8888 | No |
| api-gateway | 128 | 200 MB | 8080 | Yes |
| customers-service | 128 | 150 MB | 8081 | No |
| visits-service | 128 | 150 MB | 8082 | No |
| vets-service | 128 | 150 MB | 8083 | No |
| **Total** | **640** | **850 MB** | | |


### 4.10 Application Load Balancer

```hcl
# modules/alb/main.tf

resource "aws_lb" "main" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets           = var.public_subnet_ids  # ALB in public subnets
  
  enable_deletion_protection = false
  
  tags = {
    Name = "${var.project}-${var.environment}-alb"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_gateway.arn
  }
}

resource "aws_lb_target_group" "api_gateway" {
  name        = "${var.project}-api-gateway"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher            = "200"
    path               = "/actuator/health"
    port               = "traffic-port"
    protocol           = "HTTP"
    timeout            = 10
    unhealthy_threshold = 3
  }
  
  tags = {
    Name = "${var.project}-api-gateway-tg"
  }
}

output "dns_name" {
  value = aws_lb.main.dns_name
}

output "target_group_arn" {
  value = aws_lb_target_group.api_gateway.arn
}
```

### 4.11 RDS Module (OPTIONAL)

```hcl
# modules/rds/main.tf

# Only created when enable_rds = true

resource "aws_db_subnet_group" "main" {
  count      = var.enable_rds ? 1 : 0
  name       = "${var.project}-${var.environment}"
  subnet_ids = var.private_subnet_ids
  
  tags = {
    Name = "${var.project}-${var.environment}-db-subnet"
  }
}

resource "aws_security_group" "rds" {
  count       = var.enable_rds ? 1 : 0
  name        = "${var.project}-${var.environment}-rds-sg"
  description = "Security group for RDS"
  vpc_id      = var.vpc_id
  
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }
}

resource "aws_db_instance" "main" {
  count                  = var.enable_rds ? 1 : 0
  identifier            = "${var.project}-${var.environment}"
  engine                = "mysql"
  engine_version        = "8.0"
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  
  db_name  = "petclinic"
  username = "admin"
  password = var.db_password
  
  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = [aws_security_group.rds[0].id]
  
  multi_az               = false
  publicly_accessible    = false
  skip_final_snapshot    = true
  deletion_protection    = false
  backup_retention_period = 0
  
  tags = {
    Name = "${var.project}-${var.environment}-mysql"
  }
}

resource "aws_secretsmanager_secret" "db_credentials" {
  count = var.enable_rds ? 1 : 0
  name  = "${var.project}/${var.environment}/db-credentials"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  count     = var.enable_rds ? 1 : 0
  secret_id = aws_secretsmanager_secret.db_credentials[0].id
  
  secret_string = jsonencode({
    username = "admin"
    password = var.db_password
  })
}

output "rds_endpoint" {
  value = var.enable_rds ? aws_db_instance.main[0].endpoint : ""
}

output "db_secret_arn" {
  value = var.enable_rds ? aws_secretsmanager_secret.db_credentials[0].arn : ""
}
```


---

## 5. Root Module Configuration

### 5.1 Main Configuration

```hcl
# environments/dev/main.tf

terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "petclinic-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "petclinic-terraform-locks"
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

# Networking (VPC, Subnets, VPC Endpoints)
module "networking" {
  source = "../../modules/networking"
  
  project            = var.project
  environment        = var.environment
  aws_region         = var.aws_region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

# ECR Repositories
module "ecr" {
  source = "../../modules/ecr"
  
  project  = var.project
  services = keys(local.services)
}

# Service Discovery
module "service_discovery" {
  source = "../../modules/service-discovery"
  
  project       = var.project
  environment   = var.environment
  vpc_id        = module.networking.vpc_id
  service_names = keys(local.services)
}

# ECS Cluster
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

# ALB
module "alb" {
  source = "../../modules/alb"
  
  project               = var.project
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.networking.alb_security_group_id
}

# RDS (Optional)
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

# ECS Services
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
  
  enable_alb               = each.value.enable_alb
  target_group_arn         = module.alb.target_group_arn
  enable_service_discovery = true
  service_discovery_arn    = module.service_discovery.service_arns[each.key]
  
  enable_rds    = var.enable_rds
  rds_endpoint  = module.rds.rds_endpoint
  db_secret_arn = module.rds.db_secret_arn
  
  additional_env_vars = []
}
```


### 5.2 Variables

```hcl
# environments/dev/variables.tf

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
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
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
```

### 5.3 Outputs

```hcl
# environments/dev/outputs.tf

output "application_url" {
  description = "Application URL"
  value       = "http://${module.alb.dns_name}"
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.dns_name
}

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs_cluster.cluster_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "rds_endpoint" {
  description = "RDS endpoint (if enabled)"
  value       = var.enable_rds ? module.rds.rds_endpoint : "RDS disabled"
}
```

### 5.4 Terraform tfvars

```hcl
# environments/dev/terraform.tfvars

project            = "petclinic"
environment        = "dev"
aws_region         = "us-east-1"
instance_type      = "t2.micro"
availability_zones = ["us-east-1a", "us-east-1b"]

# Database disabled by default (uses in-memory HSQLDB)
enable_rds = false
```


---

## 6. Application Configuration (Eureka → Cloud Map Migration)

### 6.1 Overview: No Code Changes Required

AWS Cloud Map uses **DNS-based service discovery**. Services resolve each other via standard DNS lookups instead of Eureka client. ECS automatically registers/deregisters tasks with Cloud Map.

| Aspect | Eureka | AWS Cloud Map |
|--------|--------|---------------|
| Discovery method | Eureka client API | DNS lookup |
| Registration | App registers itself | ECS auto-registers |
| Health checks | Eureka heartbeat | ECS task health |
| Dependencies | Spring Cloud Netflix | None (standard DNS) |
| **Code changes** | - | **None** |
| **Config changes** | - | **2 files** |

### 6.2 Configuration Changes Summary

| File | Location | Change |
|------|----------|--------|
| `application-aws.yml` | Config repo (root) | Disable Eureka client |
| `api-gateway-aws.yml` | Config repo | Change routes from `lb://` to DNS |

**Config Repository:** https://github.com/spring-petclinic/spring-petclinic-microservices-config

### 6.3 File 1: application-aws.yml (All Services)

Create this file in the config repository root. It applies to **all services** when `SPRING_PROFILES_ACTIVE=docker,aws`.

```yaml
# spring-petclinic-microservices-config/application-aws.yml
#
# AWS Cloud Map configuration - disables Eureka, uses DNS-based discovery
# Applied to all services via SPRING_PROFILES_ACTIVE=docker,aws

spring:
  cloud:
    # Disable Spring Cloud discovery client (Eureka)
    discovery:
      enabled: false
    # Disable Spring Cloud LoadBalancer service discovery
    loadbalancer:
      enabled: false

# Disable Eureka client completely
eureka:
  client:
    enabled: false
    register-with-eureka: false
    fetch-registry: false

# Health endpoints for ECS health checks
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
  endpoint:
    health:
      probes:
        enabled: true
      show-details: always
  health:
    livenessState:
      enabled: true
    readinessState:
      enabled: true
```

### 6.4 File 2: api-gateway-aws.yml (Gateway Routes)

The API Gateway needs explicit routes since it can't use Eureka's `lb://` URIs.

**Before (Eureka - current):**
```yaml
# api-gateway.yml (current)
spring:
  cloud:
    gateway:
      routes:
        - id: customers-service
          uri: lb://customers-service        # <-- Eureka lookup
          predicates:
            - Path=/api/customer/**
```

**After (Cloud Map DNS):**
```yaml
# spring-petclinic-microservices-config/api-gateway-aws.yml
#
# API Gateway routes using AWS Cloud Map DNS names
# Services resolve via: <service-name>.petclinic.local

spring:
  cloud:
    gateway:
      routes:
        - id: vets-service
          uri: http://vets-service.petclinic.local:8083      # <-- Direct DNS
          predicates:
            - Path=/api/vet/**
          filters:
            - StripPrefix=2
            
        - id: visits-service
          uri: http://visits-service.petclinic.local:8082    # <-- Direct DNS
          predicates:
            - Path=/api/visit/**
          filters:
            - StripPrefix=2
            
        - id: customers-service
          uri: http://customers-service.petclinic.local:8081  # <-- Direct DNS
          predicates:
            - Path=/api/customer/**
          filters:
            - StripPrefix=2
```

### 6.5 How Cloud Map DNS Works

```
┌─────────────────┐     DNS Query                    ┌─────────────────────┐
│   api-gateway   │ ──────────────────────────────►  │    AWS Cloud Map    │
│                 │  customers-service.petclinic.local│    (Route 53)       │
└─────────────────┘                                  └──────────┬──────────┘
                                                                │
                            ┌───────────────────────────────────┘
                            │ DNS Response: 10.0.11.45
                            ▼
┌─────────────────┐     HTTP Request                 ┌─────────────────────┐
│   api-gateway   │ ──────────────────────────────►  │ customers-service   │
│                 │  http://10.0.11.45:8081          │   (10.0.11.45)      │
└─────────────────┘                                  └─────────────────────┘
```

**ECS Auto-Registration:**
1. ECS starts a task
2. ECS registers task IP with Cloud Map
3. Cloud Map updates DNS record
4. Other services resolve via DNS
5. ECS stops task → Cloud Map removes DNS record

### 6.6 Service DNS Names

| Service | Cloud Map DNS Name | Port |
|---------|-------------------|------|
| config-server | `config-server.petclinic.local` | 8888 |
| api-gateway | `api-gateway.petclinic.local` | 8080 |
| customers-service | `customers-service.petclinic.local` | 8081 |
| visits-service | `visits-service.petclinic.local` | 8082 |
| vets-service | `vets-service.petclinic.local` | 8083 |

### 6.7 Config Server URL

All services connect to config-server via Cloud Map DNS. Set in ECS task definition:

```json
{
  "name": "CONFIG_SERVER_URL",
  "value": "http://config-server.petclinic.local:8888"
}
```

This is already configured in the Terraform `ecs-service` module.

### 6.8 What You Don't Need

| Not Required | Reason |
|--------------|--------|
| ❌ Spring Cloud AWS dependency | Cloud Map uses standard DNS |
| ❌ Code changes to services | Config-only changes |
| ❌ Service registration code | ECS handles registration |
| ❌ Eureka server deployment | Replaced by Cloud Map |
| ❌ Custom health check code | ECS uses existing `/actuator/health` |

### 6.9 Testing the Configuration Locally

Before deploying, you can test the AWS profile locally by adding entries to `/etc/hosts`:

```bash
# /etc/hosts (for local testing)
127.0.0.1 config-server.petclinic.local
127.0.0.1 customers-service.petclinic.local
127.0.0.1 visits-service.petclinic.local
127.0.0.1 vets-service.petclinic.local
```

Then run with:
```bash
./mvnw spring-boot:run -pl spring-petclinic-api-gateway \
  -Dspring.profiles.active=aws
```

### 6.10 Migration Checklist

- [ ] Fork/clone the config repository
- [ ] Add `application-aws.yml` to config repo root
- [ ] Add `api-gateway-aws.yml` to config repo
- [ ] Commit and push config changes
- [ ] Deploy infrastructure with Terraform
- [ ] Build and push Docker images
- [ ] ECS tasks start with `SPRING_PROFILES_ACTIVE=docker,aws`
- [ ] Verify services resolve via Cloud Map DNS

---

## 7. CI/CD Pipeline

```yaml
# .github/workflows/deploy-ecs.yml
name: Build and Deploy to ECS

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  AWS_REGION: us-east-1

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: [config-server, api-gateway, customers-service, visits-service, vets-service]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: maven
      
      - name: Build with Maven
        run: ./mvnw -B package -pl spring-petclinic-${{ matrix.service }} -am -DskipTests
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2
      
      - name: Build and push Docker image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        run: |
          docker build -f docker/Dockerfile \
            --build-arg ARTIFACT_NAME=spring-petclinic-${{ matrix.service }}-3.2.4 \
            --build-arg EXPOSED_PORT=8080 \
            -t $ECR_REGISTRY/petclinic/${{ matrix.service }}:${{ github.sha }} \
            -t $ECR_REGISTRY/petclinic/${{ matrix.service }}:latest \
            spring-petclinic-${{ matrix.service }}/target
          
          docker push --all-tags $ECR_REGISTRY/petclinic/${{ matrix.service }}
  
  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Deploy to ECS
        run: |
          # Deploy config-server first, wait, then deploy others
          aws ecs update-service --cluster petclinic-dev --service config-server --force-new-deployment
          aws ecs wait services-stable --cluster petclinic-dev --services config-server
          
          for service in api-gateway customers-service visits-service vets-service; do
            aws ecs update-service --cluster petclinic-dev --service $service --force-new-deployment
          done
```


---

## 8. Cost Estimation

### Quick Test Session (8 hours)

| Resource | Calculation | Cost |
|----------|-------------|------|
| EC2 t2.micro | Free tier | $0 |
| ALB | Free tier (750 hrs) | $0 |
| ECR | Free tier (500MB) | $0 |
| CloudWatch Logs | Free tier (5GB) | $0 |
| **VPC Endpoints** | ~500MB data × $0.01/GB | **~$0.005** |
| S3 Gateway Endpoint | Free | $0 |
| Cloud Map | First 1M queries free | $0 |
| **Total** | | **< $0.01** |

### Monthly (if left running)

| Resource | Free Tier? | Cost |
|----------|------------|------|
| EC2 t2.micro | 750 hrs free | $0 |
| ALB | 750 hrs free | $0 |
| ECR | 500MB free | $0 |
| CloudWatch | 5GB free | $0 |
| VPC Endpoints | ~5GB data | ~$0.05 |
| **Total (Free Tier)** | | **~$0.05/month** |

### With RDS (Optional)

| Resource | Cost |
|----------|------|
| RDS db.t3.micro | Free tier (750 hrs/month first year) |
| After free tier | ~$15/month |
| Secrets Manager | ~$0.40/month |

---

## 9. Quick Start Commands

### Prerequisites

```bash
# Install AWS CLI
# macOS: brew install awscli
# Windows: choco install awscli

# Configure credentials
aws configure

# Install Terraform
# macOS: brew install terraform
# Windows: choco install terraform
```

### One-Time Setup

```bash
# Create S3 bucket for state
aws s3 mb s3://petclinic-terraform-state --region us-east-1

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name petclinic-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Deploy Infrastructure

```bash
cd terraform/environments/dev

# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply
```

### Build and Push Images

```bash
# Build all services
./mvnw clean package -DskipTests

# Get ECR login
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=us-east-1

aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push each service
for service in config-server api-gateway customers-service visits-service vets-service; do
  docker build -f docker/Dockerfile \
    --build-arg ARTIFACT_NAME=spring-petclinic-${service}-3.2.4 \
    --build-arg EXPOSED_PORT=8080 \
    -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/petclinic/${service}:latest \
    spring-petclinic-${service}/target
  
  docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/petclinic/${service}:latest
done
```

### Deploy Services

```bash
# Force new deployment
for service in config-server api-gateway customers-service visits-service vets-service; do
  aws ecs update-service --cluster petclinic-dev --service $service --force-new-deployment
done
```

### Access Application

```bash
# Get ALB URL
terraform output application_url

# Test
curl $(terraform output -raw alb_dns_name)/actuator/health
```

### Tear Down

```bash
# Destroy everything
terraform destroy -auto-approve
```


---

## 10. Troubleshooting

### ECS Tasks Not Starting

```bash
# Check service events
aws ecs describe-services --cluster petclinic-dev --services api-gateway \
  --query 'services[0].events[0:5]'

# Check task failures
aws ecs list-tasks --cluster petclinic-dev --service-name api-gateway --desired-status STOPPED
aws ecs describe-tasks --cluster petclinic-dev --tasks <task-arn>

# Check CloudWatch logs
aws logs tail /ecs/petclinic/api-gateway --follow
```

### VPC Endpoint Issues

```bash
# Verify endpoints exist
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=<vpc-id>"

# Test DNS resolution from EC2 instance
# SSH to instance and run:
nslookup ecr.api.us-east-1.amazonaws.com
```

### Container Can't Pull Images

Common causes:
1. VPC endpoint for `ecr.dkr` missing
2. S3 gateway endpoint missing (ECR layers stored in S3)
3. Security group blocking HTTPS (443) to endpoints

```bash
# Verify security group allows 443 to VPC endpoint SG
aws ec2 describe-security-groups --group-ids <ecs-sg-id>
```

### Services Can't Communicate

```bash
# Test Cloud Map DNS from container
# Exec into container and run:
curl http://config-server.petclinic.local:8888/actuator/health
```

---

## 11. Summary

### Architecture Highlights

| Component | Choice | Benefit |
|-----------|--------|---------|
| **Subnets** | Private | Security best practice |
| **Internet Access** | VPC Endpoints | No hourly NAT cost |
| **Compute** | EC2 t2.micro | Free tier eligible |
| **Database** | HSQLDB (default) | No RDS cost |
| **Service Discovery** | AWS Cloud Map | Native ECS integration |

### Cost Summary

| Scenario | Estimated Cost |
|----------|----------------|
| Quick test (few hours) | < $0.01 |
| Monthly (free tier) | ~$0.05 |
| Monthly (after free tier) | ~$30 |
| With RDS | +$15/month |

### Key Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `enable_rds` | `false` | Enable MySQL database |
| `instance_type` | `t2.micro` | ECS EC2 instance type |
| `db_password` | `""` | Required if RDS enabled |

---

*Document created: November 2025*
*Architecture: Private subnets with VPC Endpoints*
*Optimized for: Quick test and tear-down scenarios*


---

## 12. Step-by-Step Implementation Guide

### Prerequisites

Before starting, ensure you have:

- [ ] AWS Account (Free Tier eligible)
- [ ] AWS CLI installed and configured (`aws configure`)
- [ ] Terraform installed (v1.0+)
- [ ] Docker installed and running
- [ ] Java 17 JDK installed
- [ ] Git installed

```bash
# Verify installations
aws --version
terraform --version
docker --version
java --version
git --version
```

---

### Step 1: Create Terraform State Backend (One-Time Setup)

**Time: ~5 minutes**

```bash
# Set your AWS region
export AWS_REGION=us-east-1

# Create S3 bucket for Terraform state
aws s3 mb s3://petclinic-tfstate-$(aws sts get-caller-identity --query Account --output text) --region $AWS_REGION

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name petclinic-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $AWS_REGION

# Verify
aws s3 ls | grep petclinic
aws dynamodb describe-table --table-name petclinic-terraform-locks --query 'Table.TableStatus'
```

---

### Step 2: Create Terraform Directory Structure

**Time: ~10 minutes**

```bash
cd C:\projects\microservices\petclinic

# Create directory structure
mkdir -p terraform/environments/dev
mkdir -p terraform/modules/networking
mkdir -p terraform/modules/ecr
mkdir -p terraform/modules/ecs-cluster
mkdir -p terraform/modules/ecs-service
mkdir -p terraform/modules/alb
mkdir -p terraform/modules/service-discovery
mkdir -p terraform/modules/rds
```

Create the files based on the Terraform code in sections 4 and 5 of this document. Here's the order:

```
terraform/
├── environments/dev/
│   ├── main.tf           # Section 5.1
│   ├── variables.tf      # Section 5.2
│   ├── outputs.tf        # Section 5.3
│   └── terraform.tfvars  # Section 5.4
└── modules/
    ├── networking/
    │   ├── main.tf       # Section 4.1
    │   ├── endpoints.tf  # Section 4.2
    │   ├── security-groups.tf  # Section 4.3
    │   ├── variables.tf
    │   └── outputs.tf
    ├── ecr/
    │   └── main.tf       # Section 4.4
    ├── ecs-cluster/
    │   ├── main.tf       # Section 4.5
    │   └── iam.tf        # Section 4.6
    ├── ecs-service/
    │   └── main.tf       # Section 4.8
    ├── alb/
    │   └── main.tf       # Section 4.10
    ├── service-discovery/
    │   └── main.tf       # Section 4.7
    └── rds/
        └── main.tf       # Section 4.11
```

---

### Step 3: Create Networking Module

**Time: ~15 minutes**

```bash
# Create modules/networking/variables.tf
cat > terraform/modules/networking/variables.tf << 'EOF'
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
EOF

# Create modules/networking/outputs.tf
cat > terraform/modules/networking/outputs.tf << 'EOF'
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  value = aws_security_group.ecs.id
}

output "vpc_endpoints_security_group_id" {
  value = aws_security_group.vpc_endpoints.id
}
EOF
```

Copy the main.tf content from **Section 4.1**, endpoints.tf from **Section 4.2**, and security-groups.tf from **Section 4.3**.

---

### Step 4: Create ECR Module

**Time: ~5 minutes**

```bash
# Create modules/ecr/variables.tf
cat > terraform/modules/ecr/variables.tf << 'EOF'
variable "project" {
  type = string
}

variable "services" {
  type = list(string)
}
EOF

# Create modules/ecr/outputs.tf
cat > terraform/modules/ecr/outputs.tf << 'EOF'
output "repository_urls" {
  value = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}
EOF
```

Copy main.tf content from **Section 4.4**.

---

### Step 5: Create ECS Cluster Module

**Time: ~10 minutes**

```bash
# Create modules/ecs-cluster/variables.tf
cat > terraform/modules/ecs-cluster/variables.tf << 'EOF'
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
  type = list(string)
}

variable "ecs_security_group_id" {
  type = string
}

variable "enable_rds" {
  type    = bool
  default = false
}
EOF

# Create modules/ecs-cluster/outputs.tf
cat > terraform/modules/ecs-cluster/outputs.tf << 'EOF'
output "cluster_id" {
  value = aws_ecs_cluster.main.id
}

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "execution_role_arn" {
  value = aws_iam_role.ecs_execution.arn
}

output "task_role_arn" {
  value = aws_iam_role.ecs_task.arn
}
EOF
```

Copy main.tf from **Section 4.5** and iam.tf from **Section 4.6**.

---

### Step 6: Create Remaining Modules

**Time: ~15 minutes**

Create the following modules using code from the referenced sections:

| Module | Files | Reference |
|--------|-------|-----------|
| `modules/service-discovery` | main.tf, variables.tf, outputs.tf | Section 4.7 |
| `modules/ecs-service` | main.tf, variables.tf, outputs.tf | Section 4.8 |
| `modules/alb` | main.tf, variables.tf, outputs.tf | Section 4.10 |
| `modules/rds` | main.tf, variables.tf, outputs.tf | Section 4.11 |

---

### Step 7: Create Environment Configuration

**Time: ~10 minutes**

```bash
# Update backend bucket name in main.tf
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

cat > terraform/environments/dev/backend.tf << EOF
terraform {
  backend "s3" {
    bucket         = "petclinic-tfstate-${ACCOUNT_ID}"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "petclinic-terraform-locks"
  }
}
EOF
```

Create main.tf, variables.tf, outputs.tf, and terraform.tfvars from **Section 5**.

---

### Step 8: Initialize and Validate Terraform

**Time: ~5 minutes**

```bash
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive ../..

# Preview changes
terraform plan
```

**Expected output:** Plan showing ~40-50 resources to create.

---

### Step 9: Deploy Infrastructure

**Time: ~10-15 minutes**

```bash
# Apply infrastructure
terraform apply

# Type 'yes' when prompted

# Save outputs for later
terraform output -json > outputs.json
```

**Expected resources created:**
- VPC with public/private subnets
- VPC Endpoints (S3, ECR, ECS, CloudWatch)
- ECS Cluster with EC2 Auto Scaling Group
- ALB with target group
- ECR repositories
- Cloud Map namespace and services
- IAM roles and security groups

---

### Step 10: Fork and Update Config Repository

**Time: ~10 minutes**

```bash
# Fork the config repo (do this on GitHub first)
# https://github.com/spring-petclinic/spring-petclinic-microservices-config

# Clone your fork
cd C:\projects\microservices
git clone https://github.com/<YOUR_USERNAME>/spring-petclinic-microservices-config.git
cd spring-petclinic-microservices-config
```

Create `application-aws.yml`:

```bash
cat > application-aws.yml << 'EOF'
# AWS Cloud Map configuration - disables Eureka
spring:
  cloud:
    discovery:
      enabled: false
    loadbalancer:
      enabled: false

eureka:
  client:
    enabled: false
    register-with-eureka: false
    fetch-registry: false

management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
  endpoint:
    health:
      probes:
        enabled: true
      show-details: always
EOF
```

Create `api-gateway-aws.yml`:

```bash
cat > api-gateway-aws.yml << 'EOF'
spring:
  cloud:
    gateway:
      routes:
        - id: vets-service
          uri: http://vets-service.petclinic.local:8083
          predicates:
            - Path=/api/vet/**
          filters:
            - StripPrefix=2
        - id: visits-service
          uri: http://visits-service.petclinic.local:8082
          predicates:
            - Path=/api/visit/**
          filters:
            - StripPrefix=2
        - id: customers-service
          uri: http://customers-service.petclinic.local:8081
          predicates:
            - Path=/api/customer/**
          filters:
            - StripPrefix=2
EOF
```

Commit and push:

```bash
git add .
git commit -m "Add AWS Cloud Map configuration"
git push origin main
```

---

### Step 11: Update Application to Use Your Config Repo

**Time: ~5 minutes**

Update `spring-petclinic-config-server/src/main/resources/application.yml`:

```yaml
spring:
  cloud:
    config:
      server:
        git:
          uri: https://github.com/<YOUR_USERNAME>/spring-petclinic-microservices-config
          default-label: main
```

---

### Step 12: Build Application

**Time: ~5-10 minutes**

```bash
cd C:\projects\microservices\petclinic

# Build all services
./mvnw clean package -DskipTests

# Verify JARs created
ls -la */target/*.jar
```

---

### Step 13: Build and Push Docker Images

**Time: ~10-15 minutes**

```bash
# Get AWS account info
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-east-1

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push each service
for service in config-server api-gateway customers-service visits-service vets-service; do
  echo "Building $service..."
  
  docker build -f docker/Dockerfile \
    --build-arg ARTIFACT_NAME=spring-petclinic-${service}-3.2.4 \
    --build-arg EXPOSED_PORT=8080 \
    -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/petclinic/${service}:latest \
    spring-petclinic-${service}/target
  
  echo "Pushing $service..."
  docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/petclinic/${service}:latest
done

echo "All images pushed!"
```

Verify images in ECR:

```bash
for service in config-server api-gateway customers-service visits-service vets-service; do
  echo "$service:"
  aws ecr describe-images --repository-name petclinic/${service} --query 'imageDetails[0].imageTags'
done
```

---

### Step 14: Deploy ECS Services

**Time: ~5-10 minutes**

The services were created by Terraform but need to pull the images:

```bash
# Force new deployment to pull latest images
# Deploy config-server first (others depend on it)
aws ecs update-service \
  --cluster petclinic-dev \
  --service config-server \
  --force-new-deployment

# Wait for config-server to be stable
echo "Waiting for config-server to stabilize..."
aws ecs wait services-stable --cluster petclinic-dev --services config-server

# Deploy remaining services
for service in api-gateway customers-service visits-service vets-service; do
  echo "Deploying $service..."
  aws ecs update-service \
    --cluster petclinic-dev \
    --service $service \
    --force-new-deployment
done

echo "Waiting for all services to stabilize..."
aws ecs wait services-stable \
  --cluster petclinic-dev \
  --services api-gateway customers-service visits-service vets-service

echo "All services deployed!"
```

---

### Step 15: Verify Deployment

**Time: ~5 minutes**

```bash
# Check ECS services status
aws ecs describe-services \
  --cluster petclinic-dev \
  --services config-server api-gateway customers-service visits-service vets-service \
  --query 'services[*].[serviceName,runningCount,desiredCount]' \
  --output table

# Get ALB DNS name
ALB_DNS=$(cd terraform/environments/dev && terraform output -raw alb_dns_name)
echo "Application URL: http://$ALB_DNS"

# Test health endpoint
curl http://$ALB_DNS/actuator/health

# Test the application
curl http://$ALB_DNS/api/vet/vets
curl http://$ALB_DNS/api/customer/owners
```

Open in browser: `http://<ALB_DNS_NAME>`

---

### Step 16: View Logs (Troubleshooting)

```bash
# View logs for a service
aws logs tail /ecs/petclinic/api-gateway --follow

# View recent events
aws ecs describe-services \
  --cluster petclinic-dev \
  --services api-gateway \
  --query 'services[0].events[0:5]'
```

---

### Step 17: Tear Down (When Done Testing)

**Time: ~10 minutes**

```bash
cd terraform/environments/dev

# Destroy all resources
terraform destroy

# Type 'yes' when prompted

# Verify resources deleted
aws ecs list-clusters
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=petclinic"
```

**Optional:** Remove state backend (if no longer needed):

```bash
# Delete S3 bucket
aws s3 rb s3://petclinic-tfstate-$AWS_ACCOUNT_ID --force

# Delete DynamoDB table
aws dynamodb delete-table --table-name petclinic-terraform-locks
```

---

### Implementation Timeline Summary

| Step | Task | Time |
|------|------|------|
| 1 | Create Terraform state backend | 5 min |
| 2-7 | Create Terraform modules | 45 min |
| 8 | Initialize and validate | 5 min |
| 9 | Deploy infrastructure | 15 min |
| 10-11 | Update config repository | 15 min |
| 12 | Build application | 10 min |
| 13 | Build and push Docker images | 15 min |
| 14 | Deploy ECS services | 10 min |
| 15-16 | Verify and troubleshoot | 10 min |
| **Total** | | **~2 hours** |

---

### Quick Reference Commands

```bash
# Deploy
cd terraform/environments/dev && terraform apply

# Check services
aws ecs describe-services --cluster petclinic-dev \
  --services config-server api-gateway customers-service visits-service vets-service \
  --query 'services[*].[serviceName,runningCount]' --output table

# View logs
aws logs tail /ecs/petclinic/api-gateway --follow

# Force redeploy
aws ecs update-service --cluster petclinic-dev --service api-gateway --force-new-deployment

# Get app URL
terraform output application_url

# Tear down
terraform destroy
```


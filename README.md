# AWS ECS Infrastructure with Spring PetClinic

A production-ready Terraform infrastructure for deploying microservices to AWS ECS. Uses the Spring PetClinic application as a reference implementation.

## Overview

This project demonstrates how to deploy a microservices architecture to AWS ECS using Terraform, with a focus on:

- **Cost optimization** — Uses EC2 launch type (Free Tier eligible) with VPC Endpoints instead of NAT Gateway
- **Security** — Private subnets for ECS tasks, ALB in public subnets
- **Service discovery** — AWS Cloud Map for inter-service communication
- **Infrastructure as Code** — Modular Terraform structure for reusability

The Spring PetClinic microservices application serves as the workload, but the infrastructure patterns apply to any containerized application.

## Architecture

```
                            ┌─────────────────────────────────────────────────────────────┐
                            │                         VPC                                 │
                            │                                                             │
    Internet ──► IGW ──────►│  ┌──────────────────┐      ┌──────────────────────────┐    │
                            │  │  Public Subnets  │      │     Private Subnets      │    │
                            │  │                  │      │                          │    │
                            │  │  ┌───────────┐   │      │   ┌──────────────────┐   │    │
                            │  │  │    ALB    │───┼──────┼──►│   EC2 (ECS)      │   │    │
                            │  │  └───────────┘   │      │   │                  │   │    │
                            │  │                  │      │   │  ┌────────────┐  │   │    │
                            │  └──────────────────┘      │   │  │api-gateway │  │   │    │
                            │                            │   │  │config-srvr │  │   │    │
                            │                            │   │  │customers   │  │   │    │
                            │  ┌──────────────────────┐  │   │  │visits      │  │   │    │
                            │  │    VPC Endpoints     │  │   │  │vets        │  │   │    │
                            │  │  (ECR, ECS, Logs)    │◄─┼───┤  └────────────┘  │   │    │
                            │  └──────────────────────┘  │   └──────────────────────┘    │
                            │                            │              │                 │
                            │                            │              ▼                 │
                            │                            │      ┌──────────────┐         │
                            │                            │      │  Cloud Map   │         │
                            │                            │      │  (DNS-based  │         │
                            │                            │      │  discovery)  │         │
                            │                            │      └──────────────┘         │
                            └────────────────────────────┴────────────────────────────────┘
```

## Cost Breakdown

| Component | Cost | Notes |
|-----------|------|-------|
| EC2 (t2.micro) | Free | 750 hrs/month free tier |
| ALB | Free | 750 hrs/month free tier |
| VPC Endpoints | ~$0.01/GB | No hourly cost, only data transfer |
| ECR | Free | 500MB free storage |
| CloudWatch Logs | Free | 5GB ingestion free |
| RDS (optional) | ~$15/month | Disabled by default, uses in-memory DB |

**Estimated cost for testing: < $1/month** (assuming free tier eligibility)

## Project Structure

```
├── terraform/
│   ├── environments/
│   │   ├── dev/              # Development environment
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── terraform.tfvars
│   │   │   └── backend.tf
│   │   └── sit/              # SIT environment (multi-EC2)
│   │
│   └── modules/
│       ├── networking/       # VPC, subnets, VPC endpoints
│       ├── ecs-cluster/      # ECS cluster, EC2 ASG, IAM
│       ├── ecs-service/      # Task definitions, services
│       ├── alb/              # Application Load Balancer
│       ├── ecr/              # Container registries
│       ├── service-discovery/# AWS Cloud Map
│       └── rds/              # Optional MySQL database
│
├── docker/                   # Dockerfile for all services
├── spring-petclinic-*/       # Microservice source code
└── scripts/                  # Build and deployment scripts
```

## Quick Start

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0.0
- Docker
- Java 17 (for building the application)

### 1. Build and Push Docker Images

```bash
# Build all services
./mvnw clean install -P buildDocker

# Login to ECR
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-southeast-1.amazonaws.com

# Tag and push images
export REPOSITORY_PREFIX=<account-id>.dkr.ecr.ap-southeast-1.amazonaws.com/petclinic
export VERSION=latest
./scripts/tagImages.sh
./scripts/pushImages.sh
```

### 2. Deploy Infrastructure

```bash
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply
terraform apply
```

### 3. Access the Application

After deployment, Terraform outputs the ALB DNS name:

```bash
terraform output alb_dns_name
# Example: petclinic-dev-alb-123456.ap-southeast-1.elb.amazonaws.com
```

Open `http://<alb-dns-name>` in your browser.

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `project` | petclinic | Project name prefix |
| `environment` | dev | Environment name |
| `aws_region` | ap-southeast-1 | AWS region |
| `instance_type` | t2.micro | EC2 instance type |
| `image_tag` | latest | Docker image tag to deploy |
| `enable_rds` | false | Enable RDS MySQL (default: in-memory HSQLDB) |
| `enable_service_discovery` | false | Enable Cloud Map (for multi-EC2 setups) |

### Deploying a New Image Version

```bash
# Option 1: Update terraform.tfvars
image_tag = "v1.2.3"

# Option 2: Pass at apply time
terraform apply -var="image_tag=v1.2.3"
```

## Environments

### DEV (Single EC2)
- All services on one t2.micro instance
- Services communicate via localhost
- Cloud Map disabled
- Suitable for development and testing

### SIT (Multi-EC2)
- Services distributed across multiple instances
- Cloud Map enabled for DNS-based service discovery
- More realistic production-like setup

## Key Design Decisions

### VPC Endpoints vs NAT Gateway

We use VPC Endpoints instead of NAT Gateway to minimize costs:

| Approach | Hourly Cost | Use Case |
|----------|-------------|----------|
| VPC Endpoints | $0 (pay per GB) | Short-lived test environments |
| NAT Gateway | $0.045/hr | Long-running production |

### Service Discovery

- **DEV**: Services use `localhost` (single EC2)
- **SIT/PROD**: AWS Cloud Map provides DNS names like `vets-service.petclinic.local`

The API Gateway uses Spring Cloud Config to switch between these modes based on the `aws` profile.

### ECS Launch Type

EC2 launch type chosen over Fargate for:
- Free tier eligibility
- Better cost control for learning/testing
- More visibility into the underlying infrastructure

## Terraform Modules

| Module | Purpose |
|--------|---------|
| `networking` | VPC, subnets, security groups, VPC endpoints |
| `ecs-cluster` | ECS cluster, EC2 ASG, IAM roles |
| `ecs-service` | Task definitions, ECS services, CloudWatch logs |
| `alb` | Application Load Balancer, target groups |
| `ecr` | Container registries with lifecycle policies |
| `service-discovery` | AWS Cloud Map namespace and services |
| `rds` | Optional RDS MySQL instance |

## Cleanup

```bash
# Destroy all resources
terraform destroy

# If ECR has images, delete them first
aws ecr batch-delete-image --repository-name petclinic/api-gateway --image-ids imageTag=latest
```

## Troubleshooting

### Services not starting
Check CloudWatch Logs:
```bash
aws logs tail /ecs/petclinic/api-gateway --follow
```

### Container health checks failing
Services need 2-3 minutes to start. Check the ECS console for task status.

### Cannot pull images from ECR
Ensure VPC Endpoints for `ecr.api` and `ecr.dkr` are created and security groups allow HTTPS traffic.

## References

- [Spring PetClinic Microservices](https://github.com/spring-petclinic/spring-petclinic-microservices) — Original application
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## License

This project is licensed under the Apache License 2.0.

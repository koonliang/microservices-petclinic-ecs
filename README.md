# AWS ECS Infrastructure with Spring PetClinic

A production-ready Terraform infrastructure for deploying microservices to AWS ECS. Uses the Spring PetClinic application as a reference implementation.

## Overview

This project demonstrates how to deploy a microservices architecture to AWS ECS using Terraform, with a focus on:

- **Cost optimization** — Uses EC2 launch type (Free Tier eligible), public subnets to avoid NAT/VPC endpoint costs
- **Service discovery** — AWS Cloud Map for DNS-based inter-service communication
- **Flexible networking** — AWSVPC network mode for per-task ENI and security group control
- **Infrastructure as Code** — Modular Terraform structure for reusability

The Spring PetClinic microservices application serves as the workload, but the infrastructure patterns apply to any containerized application.

## Architecture

```
                                    ┌─────────────────────────────────────────────────────────┐
                                    │                         VPC                             │
                                    │                                                         │
         Internet ──► IGW ─────────►│  ┌────────────────────────────────────────────────┐    │
                                    │  │              Public Subnets                     │    │
                                    │  │                                                 │    │
                                    │  │  ┌───────────┐                                  │    │
                                    │  │  │    ALB    │                                  │    │
                                    │  │  └─────┬─────┘                                  │    │
                                    │  │        │                                        │    │
                                    │  │        ▼                                        │    │
                                    │  │  ┌──────────────────────────────────────────┐  │    │
                                    │  │  │           EC2 Instances (ECS)            │  │    │
                                    │  │  │                                          │  │    │
                                    │  │  │  ┌────────────┐    ┌────────────┐        │  │    │
                                    │  │  │  │config-server│   │api-gateway │        │  │    │
                                    │  │  │  └────────────┘    └────────────┘        │  │    │
                                    │  │  │  ┌────────────┐    ┌────────────┐        │  │    │
                                    │  │  │  │ customers  │    │   visits   │        │  │    │
                                    │  │  │  └────────────┘    └────────────┘        │  │    │
                                    │  │  │  ┌────────────┐                          │  │    │
                                    │  │  │  │    vets    │                          │  │    │
                                    │  │  │  └────────────┘                          │  │    │
                                    │  │  └──────────────────────────────────────────┘  │    │
                                    │  │                       │                        │    │
                                    │  │                       ▼                        │    │
                                    │  │               ┌──────────────┐                 │    │
                                    │  │               │  Cloud Map   │                 │    │
                                    │  │               │  (DNS-based  │                 │    │
                                    │  │               │  discovery)  │                 │    │
                                    │  │               └──────────────┘                 │    │
                                    │  └────────────────────────────────────────────────┘    │
                                    └─────────────────────────────────────────────────────────┘
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| config-server | 8888 | Spring Cloud Config Server |
| api-gateway | 8080 | API Gateway (public via ALB) |
| customers-service | 8081 | Customer and pet management |
| visits-service | 8082 | Visit scheduling |
| vets-service | 8083 | Veterinarian information |

## Cost Breakdown (DEV Environment)

| Component | Cost | Notes |
|-----------|------|-------|
| EC2 (5x t2.micro) | Free | 750 hrs/month free tier |
| ALB | Free | 750 hrs/month free tier |
| ECR | Free | 500MB free storage |
| CloudWatch Logs | Free | 5GB ingestion free |
| Cloud Map | Free | First 1M queries free |
| RDS (optional) | ~$15/month | Disabled by default |

**Estimated cost: < $1/month** (assuming free tier eligibility)

## Project Structure

```
├── terraform/
│   ├── environments/
│   │   ├── dev/              # Development environment
│   │   │   ├── main.tf       # Main configuration
│   │   │   ├── variables.tf  # Variable definitions
│   │   │   ├── terraform.tfvars  # Variable values
│   │   │   └── backend.tf    # State backend config
│   │   └── sit/              # SIT environment
│   │
│   └── modules/
│       ├── networking/       # VPC, subnets, security groups
│       ├── ecs-cluster/      # ECS cluster, EC2 ASG, IAM
│       ├── ecs-service/      # Task definitions, services
│       ├── alb/              # Application Load Balancer
│       ├── ecr/              # Container registries
│       ├── service-discovery/# AWS Cloud Map
│       └── rds/              # Optional MySQL database
│
├── docker/                   # Dockerfile for all services
├── spring-petclinic-*/       # Microservice source code
└── scripts/
    └── pushImagesToECR.ps1   # Build and push images to ECR
```

## Quick Start

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0.0
- Docker
- Java 17 (for building the application)
- PowerShell (for Windows) or Bash (for Linux/Mac)

### 1. Deploy Infrastructure

```bash
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply
terraform apply
```

### 2. Build and Push Docker Images

```powershell
# Build all services first
./mvnw clean install -P buildDocker

# Run the push script (PowerShell)
cd scripts
./pushImagesToECR.ps1
```

The script will:
- Login to ECR
- Build Docker images for all services
- Push images to ECR repositories

### 3. Force ECS Service Update (if images were updated)

```bash
aws ecs update-service --cluster petclinic-dev --service config-server --force-new-deployment
aws ecs update-service --cluster petclinic-dev --service api-gateway --force-new-deployment
aws ecs update-service --cluster petclinic-dev --service customers-service --force-new-deployment
aws ecs update-service --cluster petclinic-dev --service visits-service --force-new-deployment
aws ecs update-service --cluster petclinic-dev --service vets-service --force-new-deployment
```

### 4. Access the Application

After deployment, get the ALB DNS name:

```bash
terraform output alb_dns_name
```

Open `http://<alb-dns-name>` in your browser.

---

## CI/CD Pipelines

### CI Pipeline (Automatic)

The CI pipeline runs automatically on every push or pull request to the `main` branch.

**Workflow**: `.github/workflows/maven-build.yml`

| Trigger | Action |
|---------|--------|
| Push to `main` | Build and test with Maven |
| PR to `main` | Build and test with Maven |

### CD Pipeline (Manual)

The CD pipeline is triggered manually via GitHub Actions workflow dispatch.

**Workflow**: `.github/workflows/deploy.yml`

#### Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `environment` | choice | `dev` | Target environment (`dev`, `sit`) |
| `action` | choice | `deploy` | Deployment action (see below) |
| `enable_rds` | choice | `false` | Enable RDS MySQL database |
| `confirm_destroy` | string | *(empty)* | Type environment name to confirm destroy |

#### Actions

| Action | Description |
|--------|-------------|
| `deploy` | Direct ECS update - builds images, pushes to ECR, updates ECS task definitions |
| `terraform-apply` | Full Terraform apply - builds images, pushes to ECR, runs `terraform apply` |
| `terraform-destroy` | Destroys all infrastructure - requires typing environment name to confirm |

#### How to Deploy

1. Go to **Actions** → **Deploy to ECS**
2. Click **Run workflow**
3. Select environment and action
4. Click **Run workflow**

#### Deployment Flow

```
┌─────────────────────────────────────────────────────────────┐
│  Manual Trigger (workflow_dispatch)                         │
│  - Select environment (dev/sit)                             │
│  - Select action (deploy/terraform-apply/terraform-destroy) │
│  - Optional: enable_rds                                     │
└─────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
          ▼                   ▼                   ▼
   ┌─────────────┐    ┌─────────────┐    ┌─────────────────┐
   │   deploy    │    │  terraform  │    │    terraform    │
   │             │    │    apply    │    │     destroy     │
   └─────────────┘    └─────────────┘    └─────────────────┘
          │                   │                   │
          ▼                   ▼                   │
   ┌─────────────────────────────────────┐       │
   │  Build & Push Docker Images         │       │
   │  - mvn package -DskipTests          │       │
   │  - Build 5 Docker images            │       │
   │  - Tag: ${SHA::7} + latest          │       │
   │  - Push to ECR                      │       │
   └─────────────────────────────────────┘       │
          │                   │                   │
          ▼                   ▼                   ▼
   ┌─────────────┐    ┌─────────────┐    ┌─────────────────┐
   │ Update ECS  │    │  terraform  │    │    terraform    │
   │ Services    │    │    apply    │    │     destroy     │
   │ (API-based) │    │             │    │  (confirm req)  │
   └─────────────┘    └─────────────┘    └─────────────────┘
```

#### Image Tagging Strategy

Images are tagged with:
- **Short Git SHA** (e.g., `a1b2c3d`) - immutable, traceable
- **`latest`** - convenience alias for manual operations

#### GitHub Setup

**Secrets** (Settings → Secrets and variables → Actions → Secrets):
| Secret | Description |
|--------|-------------|
| `AWS_OIDC_ROLE_ARN` | IAM role ARN for GitHub OIDC authentication |
| `DB_PASSWORD` | Database password (required if `enable_rds=true`) |

**Variables** (Settings → Secrets and variables → Actions → Variables):
| Variable | Description |
|----------|-------------|
| `AWS_REGION` | AWS region (e.g., `ap-southeast-1`) |

#### IAM Role Permissions

The OIDC role needs the following permissions:

```
ECR:        GetAuthorizationToken, BatchCheckLayerAvailability, PutImage, 
            InitiateLayerUpload, UploadLayerPart, CompleteLayerUpload,
            BatchGetImage, GetDownloadUrlForLayer
ECS:        DescribeServices, UpdateService, DescribeTaskDefinition,
            RegisterTaskDefinition, DescribeClusters
S3:         GetObject, PutObject, DeleteObject (on tfstate bucket)
DynamoDB:   GetItem, PutItem, DeleteItem (on locks table)
IAM:        PassRole (for ECS task/execution roles)
Logs:       CreateLogGroup, CreateLogStream, PutLogEvents
```

---

## Configuration

### Key Variables (terraform.tfvars)

```hcl
project            = "petclinic"
environment        = "dev"
aws_region         = "ap-southeast-1"
instance_type      = "t2.micro"

# Service Discovery - enables Cloud Map DNS
enable_service_discovery = true

# EC2 instances (1 per service for isolation)
ec2_min_size         = 5
ec2_max_size         = 5
ec2_desired_capacity = 5

# Database - uses in-memory HSQLDB by default
enable_rds = false
```

### Network Mode

The infrastructure uses **AWSVPC network mode** which provides:
- Each task gets its own Elastic Network Interface (ENI)
- Tasks can have their own security groups
- Direct IP addressing for service discovery
- Required for AWS Cloud Map A-record based discovery

### Service Discovery

Services communicate using AWS Cloud Map DNS names:
- `config-server.petclinic.local:8888`
- `customers-service.petclinic.local:8081`
- `visits-service.petclinic.local:8082`
- `vets-service.petclinic.local:8083`

The API Gateway routes requests to backend services using these DNS names.

### Spring Profiles

| Profile | Description |
|---------|-------------|
| `aws` | Disables Eureka, enables Cloud Map discovery |
| `native` | Config server uses classpath config (not Git) |
| `mysql` | Uses RDS MySQL instead of HSQLDB |

ECS task definitions automatically set `SPRING_PROFILES_ACTIVE` based on configuration.

## Terraform Modules

| Module | Purpose |
|--------|---------|
| `networking` | VPC, public/private subnets, security groups |
| `ecs-cluster` | ECS cluster, EC2 Auto Scaling Group, IAM roles |
| `ecs-service` | Task definitions, ECS services with AWSVPC mode |
| `alb` | Application Load Balancer, target groups, listeners |
| `ecr` | Container registries with lifecycle policies |
| `service-discovery` | Cloud Map namespace and service registrations |
| `rds` | Optional RDS MySQL instance with Secrets Manager |

## Key Design Decisions

### Public Subnets for ECS (Cost Optimization)

For DEV environment, ECS tasks run in public subnets with public IPs. This eliminates the need for:
- NAT Gateway (~$32/month)
- VPC Endpoints (~$7/month each)

Tasks can directly access ECR, CloudWatch, and other AWS services via the Internet Gateway.

### AWSVPC Network Mode

Chosen over bridge mode for:
- AWS Cloud Map integration (A-record DNS)
- Per-task security group assignment
- Simplified networking model
- Better isolation between services

### EC2 Launch Type

EC2 launch type chosen over Fargate for:
- Free tier eligibility (t2.micro)
- Better cost control for learning/testing
- More visibility into underlying infrastructure

## Cleanup

```bash
# Destroy all resources
cd terraform/environments/dev
terraform destroy
```

If ECR repositories have images, they will be deleted automatically (force_delete = true).

## Troubleshooting

### Services not starting

Check CloudWatch Logs:
```bash
aws logs tail /ecs/petclinic/customers-service --follow
```

### Config server connection issues

Services may fail to connect to config-server on initial startup if it's not ready. The services are configured to continue without config-server (optional config import). Check if config-server is healthy:

```bash
# From an EC2 instance in the VPC
curl http://config-server.petclinic.local:8888/actuator/health
```

### Service discovery not working

Verify Cloud Map registration:
```bash
aws servicediscovery list-instances --service-id <service-id>
```

Check Route 53 hosted zone for `petclinic.local` records.

### Cannot pull images from ECR

Ensure:
1. EC2 instances have public IPs (for public subnet setup)
2. Security group allows outbound HTTPS (443)
3. IAM role has ECR permissions

## References

- [Spring PetClinic Microservices](https://github.com/spring-petclinic/spring-petclinic-microservices)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [AWS Cloud Map](https://docs.aws.amazon.com/cloud-map/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## License

This project is licensed under the Apache License 2.0.

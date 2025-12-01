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
    "ecr.api",       # ECR API calls
    "ecr.dkr",       # Docker image pulls
    "ecs",           # ECS service API
    "ecs-agent",     # ECS agent communication
    "ecs-telemetry", # ECS telemetry
    "logs",          # CloudWatch Logs
    "ssm",           # SSM Session Manager
    "ssmmessages",   # SSM Session Manager messages
    "ec2messages",   # SSM Agent messages
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

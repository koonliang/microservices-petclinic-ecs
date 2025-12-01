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

  # Allow traffic from ALB on static ports (api-gateway: 8080)
  ingress {
    description     = "Traffic from ALB (static ports)"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow traffic from ALB on dynamic port range (for dynamic port mapping)
  ingress {
    description     = "Traffic from ALB (dynamic ports)"
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

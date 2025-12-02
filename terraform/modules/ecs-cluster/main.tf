resource "aws_ecs_cluster" "main" {
  name = "${var.project}-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "disabled" # Disable to reduce costs
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

  # Public IP if using public subnets (dev), no public IP for private subnets (sit/prod)
  network_interfaces {
    associate_public_ip_address = var.use_public_subnets
    security_groups             = [var.ecs_security_group_id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config
    echo "ECS_ENABLE_CONTAINER_METADATA=true" >> /etc/ecs/ecs.config
  EOF
  )

  monitoring {
    enabled = false # Disable detailed monitoring to reduce costs
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
  vpc_zone_identifier = var.use_public_subnets ? var.public_subnet_ids : var.private_subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity

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

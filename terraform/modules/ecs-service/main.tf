resource "aws_ecs_task_definition" "service" {
  family                   = "${var.project}-${var.service_name}"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name  = var.service_name
    image = "${var.ecr_repository_url}:${var.image_tag}"

    portMappings = [{
      containerPort = var.container_port
      hostPort      = var.container_port  # Static host port (required for A records)
      protocol      = "tcp"
    }]

    environment = concat([
      {
        name  = "SPRING_PROFILES_ACTIVE"
        # config-server needs 'native' profile to use classpath config instead of Git
        value = var.service_name == "config-server" ? (
          var.enable_rds ? "native,docker,aws,mysql" : "native,docker,aws"
        ) : (
          var.enable_rds ? "docker,aws,mysql" : "docker,aws"
        )
      },
      {
        # Use Cloud Map DNS for multi-EC2, localhost for single-EC2
        name  = "CONFIG_SERVER_URL"
        value = var.enable_service_discovery ? "http://config-server.${var.discovery_namespace}:8888" : "http://localhost:8888"
      },
      {
        name  = "EUREKA_CLIENT_ENABLED"
        value = "false"
      },
      {
        # Tell Spring which mode we're in (useful for gateway routing)
        name  = "SERVICE_DISCOVERY_ENABLED"
        value = tostring(var.enable_service_discovery)
      },
      {
        # Pass the namespace so app can construct URLs if needed
        name  = "SERVICE_DISCOVERY_NAMESPACE"
        value = var.discovery_namespace
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

  # Service Discovery (only for SIT/PROD with multiple EC2s)
  dynamic "service_registries" {
    for_each = var.enable_service_discovery ? [1] : []
    content {
      registry_arn   = var.service_discovery_arn
      container_name = var.service_name
      container_port = var.container_port
    }
  }

  # ALB (only for api-gateway)
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
  retention_in_days = 3
}

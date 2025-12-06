project            = "petclinic"
environment        = "dev"
aws_region         = "ap-southeast-1"
instance_type      = "t2.micro"
availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]

# Database disabled by default (uses in-memory HSQLDB)
enable_rds = false

# Service discovery ENABLED for multi-EC2 setup
enable_service_discovery = true

# EC2 Auto Scaling - Scale EC2 instead of tasks (1 task per instance)
# - config-server
# - api-gateway
# - customers-service
# - vets-service
# - visits-service
ec2_min_size         = 5    # 1 per service minimum
ec2_max_size         = 10   # 2x services (5 services × 2 = 10) for scaling headroom
ec2_desired_capacity = 5    # Start with 5 (1 per service)

# Task Auto Scaling - DISABLED (using EC2 scaling instead due to t2.micro ENI limits)
# With awsvpc mode, t2.micro supports only 2 ENIs, so we enforce 1 task per instance
enable_autoscaling        = false  # Disable task autoscaling
max_task_count            = 1      # Max 1 task per service (will scale via EC2)
autoscaling_cpu_target    = 70     # Not used when autoscaling disabled
autoscaling_memory_target = 70     # Not used when autoscaling disabled

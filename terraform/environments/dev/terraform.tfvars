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

# Capacity Provider Scaling - ENABLED (automatically adds EC2 instances when needed)
enable_capacity_provider_scaling = true

# Task Auto Scaling - ENABLED (works with capacity provider to scale EC2 instances)
# Flow: High CPU/Memory → Task autoscaling increases desired_count →
#       No EC2 capacity → Capacity provider scales out EC2 → Task placed
enable_autoscaling        = true   # Enable task autoscaling
max_task_count            = 3      # Max 3 tasks per service (will trigger EC2 scaling)
autoscaling_cpu_target    = 70     # Scale out when CPU > 70%
autoscaling_memory_target = 70     # Scale out when memory > 70%

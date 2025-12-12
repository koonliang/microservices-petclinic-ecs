# SIT Environment Configuration
project            = "petclinic"
environment        = "sit"
aws_region         = "ap-southeast-1"
instance_type      = "t2.micro"
availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]

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
enable_autoscaling         = true   # Enable task autoscaling
enable_memory_autoscaling  = true   # Enable when task autoscaling is enabled
max_task_count             = 1      # Max 1 task per service (will scale via EC2)
autoscaling_cpu_target     = 70     # Not used when autoscaling disabled
autoscaling_memory_target  = 90     # Not used when autoscaling disabled

# RDS enabled for SIT
enable_rds = true
# db_password = "YourSecurePassword123!"  # Pass via -var or environment variable

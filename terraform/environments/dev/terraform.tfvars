project            = "petclinic"
environment        = "dev"
aws_region         = "ap-southeast-1"
instance_type      = "t2.micro"
availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]

# Database disabled by default (uses in-memory HSQLDB)
enable_rds = false

# Service discovery ENABLED for multi-EC2 setup
enable_service_discovery = true

# 5 EC2 instances (1 per service)
# - config-server
# - api-gateway
# - customers-service
# - vets-service
# - visits-service
ec2_min_size         = 5
ec2_max_size         = 8
ec2_desired_capacity = 5

# Auto Scaling Configuration
# Set to true to enable autoscaling under load
enable_autoscaling        = true
max_task_count            = 2    # Max tasks per service
autoscaling_cpu_target    = 70   # Scale when CPU exceeds 70%
autoscaling_memory_target = 70   # Scale when memory exceeds 70%

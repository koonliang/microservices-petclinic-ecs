# SIT Environment Configuration
project            = "petclinic"
environment        = "sit"
aws_region         = "ap-southeast-1"
instance_type      = "t2.micro"
availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]

# 5 EC2 instances (one per service)
ec2_min_size         = 5
ec2_max_size         = 8
ec2_desired_capacity = 5

# Auto Scaling Configuration
# Set to true to enable autoscaling under load
enable_autoscaling        = true
max_task_count            = 2    # Max tasks per service
autoscaling_cpu_target    = 70   # Scale when CPU exceeds 70%
autoscaling_memory_target = 70   # Scale when memory exceeds 70%

# RDS enabled for SIT
enable_rds = true
# db_password = "YourSecurePassword123!"  # Pass via -var or environment variable

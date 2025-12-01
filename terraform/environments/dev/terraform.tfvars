project            = "petclinic"
environment        = "dev"
aws_region         = "ap-southeast-1"
instance_type      = "t2.micro"
availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]

# Database disabled by default (uses in-memory HSQLDB)
enable_rds = false

# Enable service discovery so containers can find each other
enable_service_discovery = true

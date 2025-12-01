# Only created when enable_rds = true

resource "aws_db_subnet_group" "main" {
  count      = var.enable_rds ? 1 : 0
  name       = "${var.project}-${var.environment}"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project}-${var.environment}-db-subnet"
  }
}

resource "aws_security_group" "rds" {
  count       = var.enable_rds ? 1 : 0
  name        = "${var.project}-${var.environment}-rds-sg"
  description = "Security group for RDS"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }
}

resource "aws_db_instance" "main" {
  count             = var.enable_rds ? 1 : 0
  identifier        = "${var.project}-${var.environment}"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "petclinic"
  username = "admin"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = [aws_security_group.rds[0].id]

  multi_az                = false
  publicly_accessible     = false
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 0

  tags = {
    Name = "${var.project}-${var.environment}-mysql"
  }
}

resource "aws_secretsmanager_secret" "db_credentials" {
  count = var.enable_rds ? 1 : 0
  name  = "${var.project}/${var.environment}/db-credentials"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  count     = var.enable_rds ? 1 : 0
  secret_id = aws_secretsmanager_secret.db_credentials[0].id

  secret_string = jsonencode({
    username = "admin"
    password = var.db_password
  })
}

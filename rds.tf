resource "aws_db_subnet_group" "education_private" {
  name       = "education-private"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "Education"
  }
}

resource "aws_security_group" "rds" {
  name   = "education_rds"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "education_rds"
  }
}


resource "aws_db_parameter_group" "education" {
  name   = "education"
  family = "mysql8.0"

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "10"
  }
}

resource "aws_db_instance" "education" {
  identifier              = "education"
  instance_class          = "db.t3.micro"
  allocated_storage       = 10
  backup_retention_period = 1
  engine                  = "mysql"
  engine_version          = "8.0"
  username                = "edu"
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.education_private.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  parameter_group_name    = aws_db_parameter_group.education.name
  publicly_accessible     = false
  skip_final_snapshot     = true
  apply_immediately       = true
}

resource "aws_db_instance" "education_replica" {
  identifier             = "education-replica"
  replicate_source_db    = aws_db_instance.education.identifier
  instance_class         = "db.t3.micro"
  apply_immediately      = true
  publicly_accessible    = false
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.education.name
}

resource "aws_security_group" "lambda" {
  name   = "lambda_sg"
  vpc_id = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

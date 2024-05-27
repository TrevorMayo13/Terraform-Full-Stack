// Configure the AWS provider with the specified region and default tags.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project = "Full-Stack-Terraform"
    }
  }
}

// Generate a random name for the S3 bucket to ensure uniqueness.
resource "random_pet" "lambda_bucket_name" {
  prefix = "learn-terraform-functions"
  length = 4
}

// Create an S3 bucket using the generated random name.
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id
}

// Set the ownership controls for the S3 bucket to ensure the bucket owner has full control.
resource "aws_s3_bucket_ownership_controls" "lambda_bucket" {
  bucket = aws_s3_bucket.lambda_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

// Apply a private access control list (ACL) to the S3 bucket.
resource "aws_s3_bucket_acl" "lambda_bucket" {
  depends_on = [aws_s3_bucket_ownership_controls.lambda_bucket]

  bucket = aws_s3_bucket.lambda_bucket.id
  acl    = "private"
}

// Upload the ZIP archive to the S3 bucket.
resource "aws_s3_object" "lambda_hello_world" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "hello-world.zip"
  source = data.archive_file.lambda_hello_world.output_path

  etag = filemd5(data.archive_file.lambda_hello_world.output_path)
}

// Create the Lambda function using the uploaded ZIP archive.
resource "aws_lambda_function" "hello_world" {
  function_name = "HelloWorld"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_hello_world.key

  runtime = "nodejs20.x"
  handler = "hello.handler"

  source_code_hash = data.archive_file.lambda_hello_world.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

// Create a CloudWatch log group for the Lambda function logs.
resource "aws_cloudwatch_log_group" "hello_world" {
  name = "/aws/lambda/${aws_lambda_function.hello_world.function_name}"

  retention_in_days = 30
}

// Create an IAM role that allows Lambda to be executed.
resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

// Attach the basic execution role policy to the IAM role.
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

// Create an API Gateway for the Lambda function with HTTP protocol.
resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"
}

// Create a deployment stage for the API Gateway with automatic deployment.
resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "serverless_lambda_stage"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

// Create an integration between the API Gateway and the Lambda function.
resource "aws_apigatewayv2_integration" "hello_world" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.hello_world.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

// Create a route in the API Gateway for the Lambda function.
resource "aws_apigatewayv2_route" "hello_world" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.hello_world.id}"
}

// Create a CloudWatch log group for the API Gateway logs.
resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 30
}

// Allow the API Gateway to invoke the Lambda function.
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"

  name                 = "education"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

resource "aws_db_subnet_group" "education" {
  name       = "education"
  subnet_ids = module.vpc.public_subnets

  tags = {
    Name = "Education"
  }
}


resource "aws_security_group" "rds" {
  name   = "education_rds"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    # security_groups = [aws_security_group.lambda.id]
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
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
  db_subnet_group_name    = aws_db_subnet_group.education.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  parameter_group_name    = aws_db_parameter_group.education.name
  publicly_accessible     = true
  skip_final_snapshot     = true
  apply_immediately       = true
}

resource "aws_db_instance" "education_replica" {
  identifier             = "education-replica"
  replicate_source_db    = aws_db_instance.education.identifier
  instance_class         = "db.t3.micro"
  apply_immediately      = true
  publicly_accessible    = true
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.education.name
}

// Create a ZIP archive of the "hello-world" function source code.
data "archive_file" "lambda_hello_world" {
  type = "zip"

  source_dir  = "${path.module}/hello-world"
  output_path = "${path.module}/hello-world.zip"
}
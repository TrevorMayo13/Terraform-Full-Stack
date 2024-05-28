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

// Module for S3 Bucket
module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = var.bucket_name
  acl    = "public-read"

  versioning = {
    enabled = true
  }

  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"

  # allow cloudfront access to the bucket
  attach_policy = true
  policy        = data.aws_iam_policy_document.s3_bucket_policy.json

  website = {
    index_document = "index.html"
    error_document = "error.html"
  }
}

// Module for CloudFront
module "cloudfront" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "~> 3.2.0"

  origin = {
    s3 = {
      domain_name = module.s3_bucket.s3_bucket_bucket_regional_domain_name
      origin_id   = var.bucket_name
      origin_access_control = "s3" 
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront Distribution pointing to ${var.bucket_name}"
  default_root_object = var.cloudfront_default_root_object
  price_class         = var.cloudfront_price_class
  create_origin_access_control = true

  origin_access_control = {
    s3 = {
      description      = "CloudFront access to S3"
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }

  default_cache_behavior = {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = var.bucket_name
    forwarded_values = {
      query_string = false
      cookies = {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  viewer_certificate = {
    cloudfront_default_certificate = true
  }

  # To add an alias you must also add a certificate for that alias in ACM
  # adding certificate is mandatory for aliases - so ignoring this for now 
  # aliases = ["reactdemo.takemetoprod.com"]
}

// Disable S3 Block Public Access settings for the bucket
resource "aws_s3_bucket_public_access_block" "s3_bucket" {
  bucket = module.s3_bucket.s3_bucket_id
  block_public_acls   = false
  block_public_policy = false
  ignore_public_acls  = false
  restrict_public_buckets = false
}

// Policy to be attached to the S3 bucket to allow CloudFront access
data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${module.s3_bucket.s3_bucket_arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cloudfront.cloudfront_distribution_arn]
    }
  }
}

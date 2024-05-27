# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Input variable definitions

variable "aws_region" {
  description = "AWS region for all resources."

  type    = string
  default = "us-east-1"
}

variable "db_password" {
  description = "RDS root user password"
  sensitive   = true
}

variable "bucket_name" {
  description = "eclectic-react-bucket"
  type = string
  default = "eclectic-react-bucket"
}

variable "cloudfront_origin_path" {
  description = "The CloudFront origin path"
  type        = string
  default     = ""
}

variable "cloudfront_price_class" {
  description = "The price class for the CloudFront distribution"
  type        = string
  default     = "PriceClass_All"
}

variable "cloudfront_default_root_object" {
  description = "The default root object for the CloudFront distribution"
  type        = string
  default     = "index.html"
}
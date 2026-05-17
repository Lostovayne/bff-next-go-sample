terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # MiniStack override — empty string = AWS real
  # dev.tfvars  → http://localhost:4566
  # prod.tfvars → "" (default AWS endpoints)
  endpoints {
    accessanalyzer     = var.aws_endpoint
    apigateway         = var.aws_endpoint
    autoscaling        = var.aws_endpoint
    cloudformation     = var.aws_endpoint
    cloudwatch         = var.aws_endpoint
    dynamodb           = var.aws_endpoint
    ec2                = var.aws_endpoint
    ecr                = var.aws_endpoint
    ecs                = var.aws_endpoint
    elasticache        = var.aws_endpoint
    elb                = var.aws_endpoint
    iam                = var.aws_endpoint
    kms                = var.aws_endpoint
    lambda             = var.aws_endpoint
    rds                = var.aws_endpoint
    route53            = var.aws_endpoint
    s3                 = var.aws_endpoint
    secretsmanager     = var.aws_endpoint
    sns                = var.aws_endpoint
    sqs                = var.aws_endpoint
    ssm                = var.aws_endpoint
    sts                = var.aws_endpoint
  }

  # Skip real-AWS validation when using MiniStack
  skip_credentials_validation = var.is_local
  skip_metadata_api_check     = var.is_local
  skip_requesting_account_id  = var.is_local

  # MiniStack uses path-style S3 URLs
  s3_use_path_style = var.is_local

  # Local dev credentials (MiniStack accepts any)
  access_key = var.is_local ? "test" : null
  secret_key = var.is_local ? "test" : null

  # Don't load any AWS config profile when using MiniStack
  profile = var.is_local ? "" : null
}

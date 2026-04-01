terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state stored in S3 — shared across Jenkins runs
  # DynamoDB prevents two pipeline runs applying at same time
  backend "s3" {
    bucket         = "devops-platform-tfstate-amira"   # ← change this
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true

  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Pipeline    = "jenkins"
    }
  }
}

terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # This tree is a validate-only blueprint; when deployed, state would live in
  # a versioned S3 bucket with native lockfile locking (no DynamoDB table).
  # backend "s3" {
  #   bucket       = "platform-terraform-state"
  #   key          = "envs/staging/aws/terraform.tfstate"
  #   region       = "eu-west-1"
  #   use_lockfile = true
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = "staging"
      ManagedBy   = "terraform"
      Stack       = "platform"
    }
  }
}

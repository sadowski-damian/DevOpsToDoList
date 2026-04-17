# Terraform configuration
terraform {
  required_version = "1.14.8"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Allow any 6.* version
      version = "~> 6.0"
    }
  }
  # Remote state in wenttoprod-db workspace
  cloud {
    organization = "damian-sadowski-projekty"
    workspaces {
      name = "wenttoprod-db"
    }
  }
}
provider "aws" {
  region = "eu-central-1"

  # We add these tags to all resources created and managed by Terraform
  default_tags {
    tags = {
      Terraform   = "managed"
      Environment = "prod"
      Project     = "WentToProd"
    }
  }
}
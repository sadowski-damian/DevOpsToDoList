terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  cloud {
    organization = "damian-sadowski-projekty"
    workspaces {
      name = "devtodolist-infra"
    }
  }
}
provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      Terraform   = "managed"
      Environment = "prod"
      Project     = "DevOpsToDoList"
    }
  }
}
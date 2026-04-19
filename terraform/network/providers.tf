# Defining required Terraform version and AWS provider version
# State is stored remotely in HCP Terraform Cloud in wenttoprod-network workspace
terraform {
  required_version = "~>1.14.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  cloud {
    organization = "damian-sadowski-projekty"
    workspaces {
      name = "wenttoprod-network"
    }
  }
}

# All resources will be created in eu-central-1 region
# default_tags - applies these tags to every resource automatically so we don't have to repeat them in every resource block
provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      Terraform   = "managed"
      Environment = "prod"
      Project     = "WentToProd"
    }
  }
}
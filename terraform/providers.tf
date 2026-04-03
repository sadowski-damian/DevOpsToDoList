terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
  region = "eu-north-1"
}

provider "aws" {
  region = "eu-central-1"
  alias  = "eu-central-1"
}
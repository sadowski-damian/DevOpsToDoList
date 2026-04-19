# Data source that calls AWS and returns information about the identity Terraform is currently using to authenticate
data "aws_caller_identity" "current" {}

# Data source that returns the current AWS region - we use it to build dynamically without hardcoding eu-central-1
data "aws_region" "current" {}

# Reading outputs from the network workspace - we need subnet group and security group IDs to place RDS in the right subnets
data "terraform_remote_state" "network" {
  backend = "remote"
  config = {
    organization = "damian-sadowski-projekty"
    workspaces = {
      name = "wenttoprod-network"
    }
  }
}
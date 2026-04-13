# Current aws account ID
data "aws_caller_identity" "current" {}

# Current aws region (eu-cental-1)
data "aws_region" "current" {}

# Add remote state network since we will be using its outputs from resources (VPC, Subnets, etc...)
data "terraform_remote_state" "network" {
  backend = "remote"
  config = {
    organization = "damian-sadowski-projekty"
    workspaces = {
      name = "wenttoprod-network"
    }
  }
}
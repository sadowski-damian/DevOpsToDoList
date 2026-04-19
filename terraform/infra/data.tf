# Data source that calls AWS and returns information about the identity Terraform is currently using to authenticate
data "aws_caller_identity" "current" {}

# Data source that returns the current AWS region - we use it to build dynamically without hardcoding eu-central-1
data "aws_region" "current" {}

# IAM policy document that allows EC2 service to assume our role - both app and monitoring instances will be using this
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# IAM policy document that grants app EC2 instances permission to read SSM parameters - only /prod/* path is accessible
data "aws_iam_policy_document" "ec2_role_polices" {
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = ["arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/prod/*"]
  }
}

# IAM policy document that allows monitoring instance to list all EC2 instances - needed for Prometheus service discovery
data "aws_iam_policy_document" "monitoring_ec2_discovery" {
  statement {
    effect    = "Allow"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
}

# IAM policy document that allows monitoring instance to read the Slack webhook URL from SSM Parameter Store
data "aws_iam_policy_document" "monitoring_ssm_params" {
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/prod/slack-webhook-url"]
  }
}

# Fetching the latest Amazon Linux 2023 AMI ID from AWS SSM - this way we always use the newest image without hardcoding the ID
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Reading outputs from the network workspace - we need VPC, subnets and security group IDs to place our resources correctly
data "terraform_remote_state" "network" {
  backend = "remote"
  config = {
    organization = "damian-sadowski-projekty"
    workspaces = {
      name = "wenttoprod-network"
    }
  }
}
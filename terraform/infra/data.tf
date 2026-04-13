# List all available AZs in our region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Policy document for our EC2 instances
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

data "aws_iam_policy_document" "ec2_role_polices" {
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = ["arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/prod/*"]
  }
}

data "aws_iam_policy_document" "monitoring_ec2_discovery" {
  statement {
    effect    = "Allow"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*x86_64"]
  }
}

data "terraform_remote_state" "network" {
  backend = "remote"
  config = {
    organization = "damian-sadowski-projekty"
    workspaces = {
      name = "wenttoprod-network"
    }
  }
}
# App EC2 role - allows EC2 instances to assume the role and get temporary AWS credentials automatically
resource "aws_iam_role" "ec2_role" {
  name               = "ec2-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# Creating instance profile - this is the resource that lets us attach an IAM role directly to an EC2 instance
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# Attaching custom policy to app EC2 role - allows instances to read SSM parameters from /prod/* path only
resource "aws_iam_role_policy" "ec2_role_policy" {
  name = "ec2-role-policy"
  role = aws_iam_role.ec2_role.id

  policy = data.aws_iam_policy_document.ec2_role_polices.json
}

# Attaching AWS managed policy - gives app EC2 instances access to Systems Manager so we can connect without SSH keys
resource "aws_iam_role_policy_attachment" "ec2_role_policy_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Monitoring EC2 role - same trust policy as app role but with different permissions needed for Prometheus and Grafana
resource "aws_iam_role" "ec2_role_monitoring" {
  name               = "ec2-role-monitoring"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# Creating instance profile for monitoring instance - reousce to attach IAM role to the monitoring EC2
resource "aws_iam_instance_profile" "ec2_instance_profile_monitoring" {
  name = "ec2-instance-profile-monitoring"
  role = aws_iam_role.ec2_role_monitoring.name
}

# Attaching AWS managed policy - gives monitoring instance access to Systems Manager so we can connect without SSH keys
resource "aws_iam_role_policy_attachment" "ec2_role_policy_monitoring" {
  role       = aws_iam_role.ec2_role_monitoring.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attaching policy that allows Prometheus to discover EC2 instances automatically using AWS service discovery
resource "aws_iam_role_policy" "monitoring_ec2_discovery" {
  name   = "monitoring-ec2-discovery"
  role   = aws_iam_role.ec2_role_monitoring.id
  policy = data.aws_iam_policy_document.monitoring_ec2_discovery.json
}

# Attaching policy that allows monitoring instance to read Slack webhook URL from SSM Parameter Store
resource "aws_iam_role_policy" "monitoring_ssm_params" {
  name   = "monitoring-ssm-params"
  role   = aws_iam_role.ec2_role_monitoring.id
  policy = data.aws_iam_policy_document.monitoring_ssm_params.json
}

# Attaching S3 policy defined in network workspace - allows monitoring instance to download Grafana dashboards from S3
resource "aws_iam_role_policy_attachment" "monitoring_s3" {
  role       = aws_iam_role.ec2_role_monitoring.name
  policy_arn = data.terraform_remote_state.network.outputs.monitoring_s3_policy_arn
}
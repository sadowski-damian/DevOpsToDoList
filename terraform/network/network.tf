# Creating VPC in eu-central-1
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

# Creating public subnets in eu-central-1a and eu-central-1b
resource "aws_subnet" "public_subnet" {
  for_each          = local.public_subnets
  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name = "public-subnet-${each.key}"
    type = "public"
  }
}

# Creating private subnets in eu-central-1a and eu-central-1b
resource "aws_subnet" "private_subnet" {
  for_each          = local.private_subnets
  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name = "private-subnet-${each.key}"
    type = "private"
  }
}

# Creating internet gateway for our VPC
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "internet-gateway"
  }
}

# Creating route table for public subnets
resource "aws_route_table" "public_subnets" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "public-subnets-route-table"
  }
}

# Creating association between public subnets and our public - route table
resource "aws_route_table_association" "public_route_table_association" {
  for_each       = aws_subnet.public_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_subnets.id
}

resource "aws_security_group" "security_group_ec2" {
  name        = "security_group_ec2"
  description = "Security group rules for ec2"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "security_group_lb" {
  name        = "security_group_lb"
  description = "Security group rules for load balancer"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "security_group_monitoring" {
  name        = "security_group_monitoring"
  description = "Security group rules for monitoring instance"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "security_group_rds" {
  name        = "security_group_rds"
  description = "Security group rules for rds"
  vpc_id      = aws_vpc.main.id
}

# EC2 rules - inbound from ALB and monitoring on app port, inbound from monitoring on node exporter port
resource "aws_vpc_security_group_ingress_rule" "ec2_from_lb" {
  security_group_id            = aws_security_group.security_group_ec2.id
  referenced_security_group_id = aws_security_group.security_group_lb.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ec2_from_monitoring_app" {
  security_group_id            = aws_security_group.security_group_ec2.id
  referenced_security_group_id = aws_security_group.security_group_monitoring.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ec2_from_monitoring_node_exporter" {
  security_group_id            = aws_security_group.security_group_ec2.id
  referenced_security_group_id = aws_security_group.security_group_monitoring.id
  from_port                    = 9100
  to_port                      = 9100
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ec2_all_outbound" {
  security_group_id = aws_security_group.security_group_ec2.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ALB rules - inbound HTTP and HTTPS from internet
resource "aws_vpc_security_group_ingress_rule" "lb_http" {
  security_group_id = aws_security_group.security_group_lb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "lb_https" {
  security_group_id = aws_security_group.security_group_lb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "lb_all_outbound" {
  security_group_id = aws_security_group.security_group_lb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "monitoring_all_outbound" {
  security_group_id = aws_security_group.security_group_monitoring.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# RDS rules - inbound PostgreSQL from EC2 only
resource "aws_vpc_security_group_ingress_rule" "rds_from_ec2" {
  security_group_id            = aws_security_group.security_group_rds.id
  referenced_security_group_id = aws_security_group.security_group_ec2.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_db_subnet_group" "db_rds_subnet_group" {
  name       = "db-rds-subnet-group"
  subnet_ids = [aws_subnet.private_subnet[data.aws_availability_zones.available.names[0]].id, aws_subnet.private_subnet[data.aws_availability_zones.available.names[1]].id]

  tags = {
    Name = "RDS subnet group"
  }
}

resource "aws_route53_zone" "main" {
  name = "damiansadowski.cloud"
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "*.damiansadowski.cloud"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "site_cert_dns" {
  allow_overwrite = true
  name            = tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_name
  records         = [tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_value]
  type            = tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_type
  zone_id         = aws_route53_zone.main.id
  ttl             = 60
}

resource "aws_acm_certificate_validation" "site_cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [aws_route53_record.site_cert_dns.fqdn]
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "VPC-FlowLogs"
  retention_in_days = 30
}

data "aws_iam_policy_document" "vpc_flow_logs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "vpc_flow_logs_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name               = "vpc-flow-logs-role"
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume.json
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name   = "vpc-flow-logs-policy"
  role   = aws_iam_role.vpc_flow_logs.id
  policy = data.aws_iam_policy_document.vpc_flow_logs_policy.json
}

resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
}

resource "aws_guardduty_detector" "main" {
  enable = true
}

resource "aws_cloudtrail" "main" {
  name                          = "main-trail"
  s3_bucket_name                = aws_s3_bucket.monitoring_config.id
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_log_file_validation    = true
}
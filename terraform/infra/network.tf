# Creating Elastic IPs for both NAT gateways - static public IPs that are assigned to NAT gateways
resource "aws_eip" "elastic_ip_nat_gateway_first" {
  domain = "vpc"
}

resource "aws_eip" "elastic_ip_nat_gateway_second" {
  domain = "vpc"
}

# Creating NAT gateways in both public subnets - they allow private EC2 instances to reach the internet for outbound traffic
# Each private subnet gets its own NAT gateway in the same AZ
resource "aws_nat_gateway" "nat_gateway_first" {
  subnet_id     = data.terraform_remote_state.network.outputs.first_public_subnet_id
  allocation_id = aws_eip.elastic_ip_nat_gateway_first.id

  tags = {
    Name = "nat-gateway-first"
  }
}

resource "aws_nat_gateway" "nat_gateway_second" {
  subnet_id     = data.terraform_remote_state.network.outputs.second_public_subnet_id
  allocation_id = aws_eip.elastic_ip_nat_gateway_second.id

  tags = {
    Name = "nat-gateway-second"
  }
}

# Creating route tables for private subnets - any outbound traffic goes through the NAT gateway instead of the internet gateway
# Each private subnet has its own route table pointing to the NAT gateway in the same AZ
resource "aws_route_table" "first_private_subnet" {
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway_first.id
  }

  tags = {
    Name = "first-private-subnet-route-table"
  }
}

resource "aws_route_table" "second_private_subnet" {
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway_second.id
  }

  tags = {
    Name = "second-private-subnet-route-table"
  }
}

# Creating associations between private subnets and their route tables - each subnet gets its own route table with dedicated NAT gateway
resource "aws_route_table_association" "first_private_route_table_association" {
  subnet_id      = data.terraform_remote_state.network.outputs.first_private_subnet_id
  route_table_id = aws_route_table.first_private_subnet.id
}

resource "aws_route_table_association" "second_private_route_table_association" {
  subnet_id      = data.terraform_remote_state.network.outputs.second_private_subnet_id
  route_table_id = aws_route_table.second_private_subnet.id
}

# Creating Application Load Balancer in public subnets - it receives traffic from the internet and distributes it across EC2 instances
# enable_cross_zone_load_balancing - spreads traffic evenly across all instances regardless of which AZ they are in
# drop_invalid_header_fields - drops requests with malformed HTTP headers, adds protection against certain attacks
# access_logs - all requests are logged to S3 so we have full visibility into what traffic hits our application
#tfsec:ignore:aws-elb-alb-not-public
resource "aws_lb" "main_alb" {
  name                             = "main-alb"
  load_balancer_type               = "application"
  security_groups                  = [data.terraform_remote_state.network.outputs.lb_security_group]
  subnets                          = [data.terraform_remote_state.network.outputs.first_public_subnet_id, data.terraform_remote_state.network.outputs.second_public_subnet_id]
  enable_cross_zone_load_balancing = true
  drop_invalid_header_fields       = true

  access_logs {
    enabled = true
    bucket  = data.terraform_remote_state.network.outputs.monitoring_config_bucket_name
    prefix  = "alb-logs"
  }

  tags = {
    Name = "main-alb"
  }
}

# Creating target group for ALB - defines where ALB should forward traffic and how to check if instances are healthy
# We use HTTP because ALB handles TLS termination, so traffic between ALB and EC2 is plain HTTP on port 8080
# health_check - ALB calls /health every 20 seconds, instance needs 4 consecutive 200 responses to be considered healthy
resource "aws_lb_target_group" "alb_target_group" {
  name     = "lb-target-group"
  port     = data.terraform_remote_state.network.outputs.app_port
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.network.outputs.vpc_id

  health_check {
    path                = "/health"
    port                = tostring(data.terraform_remote_state.network.outputs.app_port)
    healthy_threshold   = 4
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 20
    matcher             = "200"
  }
}

# Creating HTTPS listener on port 443 - this is the main listener that receives encrypted traffic and forwards it to EC2 instances
# We attach our ACM wildcard certificate here so ALB handles all TLS encryption and decryption
#tfsec:ignore:aws-elb-http-not-used
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = data.terraform_remote_state.network.outputs.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_group.arn
  }
}

# Creating HTTP listener on port 80 - it does not serve any traffic, it just redirects everything to HTTPS with 301
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Creating Route53 DNS record that points our domain to the ALB
# We use an alias record instead of CNAME because ALB DNS name can change - alias always resolves to the current ALB IPs
resource "aws_route53_record" "app" {
  zone_id = data.terraform_remote_state.network.outputs.route_53_zone_id
  name    = "wenttoprod.damiansadowski.cloud"
  type    = "A"

  alias {
    name                   = aws_lb.main_alb.dns_name
    zone_id                = aws_lb.main_alb.zone_id
    evaluate_target_health = true
  }
}

# Uploading Grafana dashboard JSON file to S3 - monitoring instance downloads it on startup to provision the dashboard automatically
# etag - Terraform detects when the file changes and re-uploads it, so the dashboard in S3 is always up to date
resource "aws_s3_object" "grafana_dashboard" {
  bucket = data.terraform_remote_state.network.outputs.monitoring_config_bucket_name
  key    = "grafana/node-exporter.json"
  source = "./monitoring/grafana/dashboards/node-exporter.json"
  etag   = filemd5("./monitoring/grafana/dashboards/node-exporter.json")
}

# Creating WAF and attaching it to the ALB - protects our application from common web attacks
# AWSManagedRulesCommonRuleSet - AWS managed rules that block OWASP Top 10 threats like SQL injection and XSS
# RateBasedRule - blocks any single IP that sends more than 1000 requests in 5 minutes to prevent abuse
resource "aws_wafv2_web_acl" "alb_waf" {
  name  = "alb-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "RateBasedrule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 0

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "MainWAF"
    sampled_requests_enabled   = true
  }
}

# Associating WAF with our ALB - without this the WAF exists but does not inspect any traffic
resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = aws_lb.main_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.alb_waf.arn
}
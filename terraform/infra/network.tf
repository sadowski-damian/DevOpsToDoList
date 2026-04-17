# Creating Elastic IPs for our Both NAT gateways
resource "aws_eip" "elastic_ip_nat_gateway_first" {
  domain = "vpc"
}

resource "aws_eip" "elastic_ip_nat_gateway_second" {
  domain = "vpc"
}


# Creating a NAT Gateway in a both public subnets so our private subnets have outbound internet connection
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

# Creating route table for private subnets forwarding to dedicated NAT Gateways
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

# Creating association between private subnets and our private route tables
resource "aws_route_table_association" "first_private_route_table_association" {
  subnet_id      = data.terraform_remote_state.network.outputs.first_private_subnet_id
  route_table_id = aws_route_table.first_private_subnet.id
}

resource "aws_route_table_association" "second_private_route_table_association" {
  subnet_id      = data.terraform_remote_state.network.outputs.second_private_subnet_id
  route_table_id = aws_route_table.second_private_subnet.id
}

# Create application load balancer so we can spread traffic between our ec2 instances
# We deploy alb in our public subnets
# Also we enabled cross_zone_load_balancing which will result in more efficient traffic spreading
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

# Create target group for our application load balancer
# Our app will listen on port 8080 also we use http because ALB handles TLS termination
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

# Create listener for alb
# Listener catches incoming traffic from the internet and forwards it to our target group
# We ve got SSL now
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

resource "aws_s3_object" "grafana_dashboard" {
  bucket = data.terraform_remote_state.network.outputs.monitoring_config_bucket_name
  key    = "grafana/node-exporter.json"
  source = "./monitoring/grafana/dashboards/node-exporter.json"
  etag   = filemd5("./monitoring/grafana/dashboards/node-exporter.json")
}

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

resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = aws_lb.main_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.alb_waf.arn
}
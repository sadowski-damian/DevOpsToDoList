# Creating Elastic IP for our future NAT Gateway use
resource "aws_eip" "elastic_ip_nat_gateway" {
  domain = "vpc"
}

# Creating a single NAT Gateway in a first public subnet so our private subnets have outbound internet connection
resource "aws_nat_gateway" "nat_gateway" {
  subnet_id     = data.terraform_remote_state.network.outputs.first_public_subnet_id
  allocation_id = aws_eip.elastic_ip_nat_gateway.id

  tags = {
    Name = "nat-gateway"
  }
}

# Creating route table for private subnets forwarding to NAT Gateway
resource "aws_route_table" "private_subnets" {
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "private-subnets-route-table"
  }
}

# Creating association between private subnets and our private - route table
resource "aws_route_table_association" "private_route_table_association" {
  for_each       = toset([data.terraform_remote_state.network.outputs.first_private_subnet_id, data.terraform_remote_state.network.outputs.second_private_subnet_id])
  subnet_id      = each.value
  route_table_id = aws_route_table.private_subnets.id
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
# HTTP is used because no SSL certificate is configured for this learning project
#tfsec:ignore:aws-elb-http-not-used
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_group.arn
  }
}

resource "aws_s3_object" "grafana_dashboard" {
  bucket = data.terraform_remote_state.network.outputs.monitoring_config_bucket_name
  key    = "grafana/node-exporter.json"
  source = "./monitoring/grafana/dashboards/node-exporter.json"
  etag   = filemd5("./monitoring/grafana/dashboards/node-exporter.json")
}
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

# Creating Elastic IP for our future NAT Gateway use
resource "aws_eip" "elastic_ip_nat_gateway" {
  domain = "vpc"
}

# Creating a single NAT Gateway in a first public subnet so our private subnets have outbound internet connection
resource "aws_nat_gateway" "nat_gateway" {
  subnet_id     = aws_subnet.public_subnet[data.aws_availability_zones.available.names[0]].id
  allocation_id = aws_eip.elastic_ip_nat_gateway.id

  tags = {
    Name = "nat-gateway"
  }

  depends_on = [aws_internet_gateway.internet_gateway]
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

# Creating route table for private subnets forwarding to NAT Gateway
resource "aws_route_table" "private_subnets" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "private-subnets-route-table"
  }
}

# Creating association between public subnets and our public - route table
resource "aws_route_table_association" "public_route_table_association" {
  for_each       = aws_subnet.public_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_subnets.id
}

# Creating association between private subnets and our private - route table
resource "aws_route_table_association" "private_route_table_association" {
  for_each       = aws_subnet.private_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_subnets.id
}


# Configuration of different security groups for our app
# Outbound of our EC2 instances - we allow for all outbound traffic
# Inbound to - we allow traffic from port 8080 (in which our app runs) to the same port && security groups of lb and monitoring instance
resource "aws_security_group" "security_group_ec2" {
  name        = "security_group_ec2"
  description = "Security group rules for ec2"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
  }
  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.security_group_lb.id, aws_security_group.security_group_monitoring.id]
  }

  ingress {
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.security_group_monitoring.id]
  }
}

# Security group for load balancer
# Inbound: We allow traffic from http (80) and https (443) from any cidr using tcp
# Outbound: We allow all trafic out of our load balancer
resource "aws_security_group" "security_group_lb" {
  name        = "security_group_lb"
  description = "Security group rules for load balancer"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
  }
}

# Security group for RDS
# Inbound: We allow traffic from ec2 security group on port 3306 
# Outbound: We allow all trafic out of our rds instance
# resource "aws_security_group" "security_group_rds" {
#   name        = "security_group_rds"
#   description = "Security group rules for rds"
#   vpc_id      = aws_vpc.main.id
# 
#   ingress {
#     from_port       = 3306
#     to_port         = 3306
#     protocol        = "tcp"
#     security_groups = [aws_security_group.security_group_ec2.id]
#   }
# }


# Security group for our monitoringinstance
# Inbound: We allow traffic from ports 9090 and to 9090, and from grafana on port 3000 to port 3000
# Outbound: We allow all trafic out of our monitoring instance
resource "aws_security_group" "security_group_monitoring" {
  name        = "security_group_monitoring"
  description = "Security group rules for monitoring instance"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    cidr_blocks = ["10.0.0.0/16"]
    protocol    = "tcp"
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    cidr_blocks = ["10.0.0.0/16"]
    protocol    = "tcp"
  }
}


# resource "aws_db_subnet_group" "db_rds_subnet_group" {
#   name       = "db-rds-subnet-group"
#   subnet_ids = [aws_subnet.private_subnet[data.aws_availability_zones.available.names[0]].id, aws_subnet.private_subnet[data.aws_availability_zones.available.names[1]].id]
# 
#   tags = {
#     Name = "RDS subnet group"
#   }
# }


# Create application load balancer so we can spread traffic between our ec2 instances
# We deploy alb in our public subnets
# Also we enabled cross_zone_load_balancing which will result in more efficient traffic spreading
resource "aws_lb" "main_alb" {
  name                             = "main-alb"
  load_balancer_type               = "application"
  security_groups                  = [aws_security_group.security_group_lb.id]
  subnets                          = [for subnet in aws_subnet.public_subnet : subnet.id]
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "main-alb"
  }
}

# Create target group for our application load balancer
# Our app will listen on port 8080 also we use http because ALB handles TLS termination
resource "aws_lb_target_group" "alb_target_group" {
  name     = "lb-target-group"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/health"
    port                = tostring(var.app_port)
    healthy_threshold   = 4
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 20
    matcher             = "200"
  }
}

# Create listener for alb
# Listener catches incoming traffic from the internet and forwards it to our target group
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_group.arn
  }
}
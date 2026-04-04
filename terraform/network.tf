# Creating VPC in eu-central-1
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

# Creating public subnets in eu-central-1a and eu-central-1b
resource "aws_subnet" "public-subnet" {
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
resource "aws_subnet" "private-subnet" {
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
resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "internet-gateway"
  }
}

# Creating Elastic IP for our future NAT Gateway use
resource "aws_eip" "elastic-ip-nat-gateway" {
  depends_on = [aws_internet_gateway.internet-gateway]
  domain     = "vpc"
}

# Creating a single NAT Gateway in a first public subnet so our private subnets have outbound internet connection
resource "aws_nat_gateway" "nat-gateway" {
  subnet_id     = aws_subnet.public-subnet[data.aws_availability_zones.available.names[0]].id
  allocation_id = aws_eip.elastic-ip-nat-gateway.id

  tags = {
    Name = "nat-gateway"
  }

  depends_on = [aws_internet_gateway.internet-gateway]
}

# Creating route table for public subnets
resource "aws_route_table" "public-subnets" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway.id
  }

  tags = {
    Name = "public-subnets-route-table"
  }
}

# Creating route table for private subnets forwarding to NAT Gateway
resource "aws_route_table" "private-subnets" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gateway.id
  }

  tags = {
    Name = "private-subnets-route-table"
  }
}

# Creating association between public subnets and our public - route table
resource "aws_route_table_association" "public-route-table-association" {
  for_each       = aws_subnet.public-subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public-subnets.id
}

# Creating association between private subnets and our private - route table
resource "aws_route_table_association" "private-route-table-association" {
  for_each       = aws_subnet.private-subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private-subnets.id
}

/*
# Configuration of different security groups for our app
resource "aws_security_group" "security-group-ec2" {
  egress {
  }
  ingress {
  }
}
*/

# Security group for load balancer
# Inbound: We allow traffic from http (80) and https (443) from any cidr using tcp
# Outbound: We allow all trafic out of our load balancer
resource "aws_security_group" "security-group-lb" {
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
/*
resource "aws_security_group" "security-group-rds" {
  egress {
  }

  ingress {
  }
}

resource "aws_security_group" "security-group-prometheus" {
  egress {
  }

  ingress {
  }
}
*/

# Create application load balancer so we can spread traffic between our ec2 instances
# We deploy alb in our public subnets
# Also we enabled cross_zone_load_balancing which will result in more efficient traffic spreading
resource "aws_lb" "main-alb" {
  name                             = "main-alb"
  load_balancer_type               = "application"
  security_groups                  = [aws_security_group.security-group-lb.id]
  subnets                          = [for subnet in aws_subnet.public-subnet : subnet.id]
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "main-alb"
  }
}

# Create target group for our application load balancer
# Our app will listen on port 8080 also we use http because ALB handles TLS termination
resource "aws_lb_target_group" "alb-target-group" {
  name     = "lb-target-group"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

# Create listener for alb
# Listener catches incoming traffic from the internet and forwards it to our target group
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.main-alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb-target-group.arn
  }
}
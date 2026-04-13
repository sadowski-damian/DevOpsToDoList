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

# Security group for RDS
# Inbound: We allow traffic from ec2 security group on port 5432
# Outbound: We allow all trafic out of our rds instance
resource "aws_security_group" "security_group_rds" {
  name        = "security_group_rds"
  description = "Security group rules for rds"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.security_group_ec2.id]
  }
}

resource "aws_db_subnet_group" "db_rds_subnet_group" {
  name       = "db-rds-subnet-group"
  subnet_ids = [aws_subnet.private_subnet[data.aws_availability_zones.available.names[0]].id, aws_subnet.private_subnet[data.aws_availability_zones.available.names[1]].id]

  tags = {
    Name = "RDS subnet group"
  }
}
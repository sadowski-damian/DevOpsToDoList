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
  domain   = "vpc"
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
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gateway.id
  }

  tags = {
    Name = "private-subnets-route-table"
  }
}

resource "aws_route_table_association" "public-route-table-association" {
  for_each = aws_subnet.public-subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public-subnets.id
}

resource "aws_route_table_association" "private-route-table-association" {
  for_each = aws_subnet.private-subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private-subnets.id
}
locals {
  public_subnets = {
    (data.aws_availability_zones.available.names[0]) = "10.0.1.0/24"
    (data.aws_availability_zones.available.names[1]) = "10.0.2.0/24"
  }
  private_subnets = {
    (data.aws_availability_zones.available.names[0]) = "10.0.101.0/24"
    (data.aws_availability_zones.available.names[1]) = "10.0.102.0/24"
  }
}
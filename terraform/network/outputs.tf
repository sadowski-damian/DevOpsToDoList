output "first_public_subnet_id" {
  description = "ID of our first private subnet"
  value       = aws_subnet.public_subnet[data.aws_availability_zones.available.names[0]].id
}

output "second_public_subnet_id" {
  description = "ID of our second public subnet"
  value       = aws_subnet.public_subnet[data.aws_availability_zones.available.names[1]].id
}

output "first_private_subnet_id" {
  description = "ID of our first private subnet"
  value       = aws_subnet.private_subnet[data.aws_availability_zones.available.names[0]].id
}

output "second_private_subnet_id" {
  description = "ID of our second private subnet"
  value       = aws_subnet.private_subnet[data.aws_availability_zones.available.names[1]].id
}

output "vpc_id" {
  description = "ID of our VPC"
  value       = aws_vpc.main.id
}

output "ec2_security_group" {
  description = "ID of ec2 security group"
  value       = aws_security_group.security_group_ec2.id
}

output "lb_security_group" {
  description = "ID of lb security group"
  value       = aws_security_group.security_group_lb.id
}

output "monitoring_security_group" {
  description = "ID of monitoring security group"
  value       = aws_security_group.security_group_monitoring.id
}

output "rds_security_group" {
  description = "ID of lb security group"
  value       = aws_security_group.security_group_rds.id
}

output "subnet_group_id" {
  description = "ID db subnet group"
  value       = aws_db_subnet_group.db_rds_subnet_group.id
}

output "app_port" {
  description = "Port number of our app"
  value       = var.app_port
}

output "monitoring_config_bucket_name" {
  description = "S3 Bucket name"
  value       = aws_s3_bucket.monitoring_config.id
}

output "monitoring_config_bucket_arn" {
  description = "S3 Bucket arn"
  value       = aws_s3_bucket.monitoring_config.arn
}

output "monitoring_s3_policy_arn" {
  description = "ARN of the IAM policy for monitoring EC2 S3 access"
  value       = aws_iam_policy.monitoring_s3.arn
}

output "acm_certificate_arn" {
  description = "Arn of our ACM certificate"
  value       = aws_acm_certificate_validation.site_cert_validation.certificate_arn
}

output "route_53_zone_id" {
  description = "ID of our route 53 hosted zone"
  value       = aws_route53_zone.main.id
}
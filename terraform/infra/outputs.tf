output "alb_dns_name" {
  description = "ALB dns name"
  value       = aws_lb.main_alb.dns_name
}

output "monitoring_private_ip" {
  description = "Monitoring instance - private IP"
  value       = aws_instance.ec2_monitoring_instance.private_ip
}
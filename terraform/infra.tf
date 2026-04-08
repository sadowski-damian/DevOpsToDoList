# ASG Launch template
resource "aws_launch_template" "ec2-launch-template" {
  name                   = "ec2-launch-template"
  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2-instance-profile.name
  }

  image_id      = var.amazon-linux-2023-6_1-AMI
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.security-group-ec2.id]
  }

  user_data = filebase64("./UserDataScripts/userDataEC2.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "EC2-instance-ASG"
    }
  }
}

# ASG
resource "aws_autoscaling_group" "main-asg" {
  vpc_zone_identifier = [for subnet in aws_subnet.private-subnet : subnet.id]
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.alb-target-group.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.ec2-launch-template.id
    version = "$Latest"
  }
}
# resource "aws_db_instance" "rds-db-instance" {
#   allocated_storage      = 10
#   db_name                = "myrds_db"
#   engine                 = "mysql"
#   engine_version         = "8.0"
#   instance_class         = "db.t3.micro"
#   username               = ""
#   password               = ""
#   parameter_group_name   = "default.mysql8.0"
#   skip_final_snapshot    = true
#   db_subnet_group_name   = aws_db_subnet_group.db-rds-subnet-group.name
#   vpc_security_group_ids = [aws_security_group.security-group-rds.id]
# }

resource "aws_instance" "ec2-prometheus-instance" {
  ami                    = var.amazon-linux-2023-6_1-AMI
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private-subnet[data.aws_availability_zones.available.names[0]].id
  vpc_security_group_ids = [aws_security_group.security-group-prometheus.id]
  user_data              = file("./UserDataScripts/userDataPrometheus.sh")
  iam_instance_profile   = aws_iam_instance_profile.ec2-instance-profile-prometheus.name

  tags = {
    Name = "ec2-prometheus-instance"
  }
}
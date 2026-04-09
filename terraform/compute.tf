# ASG Launch template
resource "aws_launch_template" "ec2_launch_template" {
  name                   = "ec2-launch-template"
  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }

  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.security_group_ec2.id]
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
resource "aws_autoscaling_group" "main_asg" {
  vpc_zone_identifier       = [for subnet in aws_subnet.private_subnet : subnet.id]
  desired_capacity          = 1
  max_size                  = 2
  min_size                  = 1
  target_group_arns         = [aws_lb_target_group.alb_target_group.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 600

  launch_template {
    id      = aws_launch_template.ec2_launch_template.id
    version = "$Latest"
  }
}
# resource "aws_db_instance" "rds_db_instance" {
#   allocated_storage      = 10
#   db_name                = "myrds_db"
#   engine                 = "mysql"
#   engine_version         = "8.0"
#   instance_class         = "db.t3.micro"
#   username               = ""
#   password               = ""
#   parameter_group_name   = "default.mysql8.0"
#   skip_final_snapshot    = true
#   db_subnet_group_name   = aws_db_subnet_group.db_rds_subnet_group.name
#   vpc_security_group_ids = [aws_security_group.security_group_rds.id]
# }
#

resource "aws_instance" "ec2_prometheus_instance" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet[data.aws_availability_zones.available.names[0]].id
  vpc_security_group_ids = [aws_security_group.security_group_prometheus.id]
  user_data              = file("./UserDataScripts/userDataPrometheus.sh")
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile_prometheus.name

  tags = {
    Name = "ec2-prometheus-instance"
  }
}
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


  user_data = filebase64("./userDataEC2.sh")

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

  launch_template {
    id      = aws_launch_template.ec2-launch-template.id
    version = "$Latest"
  }
}
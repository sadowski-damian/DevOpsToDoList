# ASG Launch template
resource "aws_launch_template" "ec2_launch_template" {
  name                   = "ec2-launch-template"
  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }

  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [data.terraform_remote_state.network.outputs.ec2_security_group]
  }

  user_data = filebase64("./UserDataScripts/userDataAppEC2.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "EC2-app-instance-ASG"
    }
  }
}

# ASG
resource "aws_autoscaling_group" "main_asg" {
  name                      = "main-asg"
  vpc_zone_identifier       = [data.terraform_remote_state.network.outputs.first_private_subnet_id, data.terraform_remote_state.network.outputs.second_private_subnet_id]
  desired_capacity          = 2
  max_size                  = 4
  min_size                  = 1
  target_group_arns         = [aws_lb_target_group.alb_target_group.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 120
  wait_for_capacity_timeout = "5m"

  launch_template {
    id      = aws_launch_template.ec2_launch_template.id
    version = aws_launch_template.ec2_launch_template.latest_version
  }
}

resource "aws_instance" "ec2_monitoring_instance" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.instance_type
  subnet_id              = data.terraform_remote_state.network.outputs.first_private_subnet_id
  vpc_security_group_ids = [data.terraform_remote_state.network.outputs.monitoring_security_group]
  user_data_base64 = base64encode(templatefile("./UserDataScripts/userDataMonitoringEC2.sh", {
    prometheus_config          = file("./monitoring/prometheus/prometheus.yaml")
    grafana_datasource         = file("./monitoring/grafana/provisioning/datasources/datasource.yaml")
    grafana_dashboard_provider = file("./monitoring/grafana/provisioning/dashboards/dashboard.yaml")
    docker_compose             = file("./monitoring/monitoring-compose.yaml")
    grafana_dashboard          = file("./monitoring/grafana/dashboards/node-exporter.json")
  }))

  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile_monitoring.name

  tags = {
    Name = "EC2-monitoring-instance"
  }
}
# Creating launch template for our ASG - it defines what every new EC2 instance will look like when ASG creates one 
# update_default_version - every time we update the template it automatically becomes the new default version used by ASG
# image_id - we use the latest AL2023 AMI fetched dynamically from AWS SSM so we never run on an outdated image
# http_tokens required - enforces IMDSv2 on every instance, protects against SSRF attacks on the metadata endpoint
# user_data - startup script that installs Docker, pulls our app image from GHCR and starts Node Exporter for metrics
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

  metadata_options {
    http_tokens = "required"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "EC2-app-instance-ASG"
    }
  }
}

# Creating Auto Scaling Group - it maintains the desired number of EC2 instances and replaces unhealthy ones automatically
# vpc_zone_identifier - we spread instances across both private subnets so if one AZ goes down we still have capacity
# health_check_type ELB - ASG uses ALB health checks to decide if instance is healthy, not just EC2 status checks
# health_check_grace_period - gives each instance 120 seconds to finish starting before ASG begins health checking it
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

# Creating monitoring EC2 instance in private subnet - runs Prometheus, Grafana and Alertmanager via Docker Compose
# templatefile - we inject all monitoring config files directly into the user data script at apply time
# root_block_device encrypted - disk is encrypted so all collected metrics are protected at rest
resource "aws_instance" "ec2_monitoring_instance" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.instance_type
  subnet_id              = data.terraform_remote_state.network.outputs.first_private_subnet_id
  vpc_security_group_ids = [data.terraform_remote_state.network.outputs.monitoring_security_group]
  user_data_base64 = base64encode(templatefile("./UserDataScripts/userDataMonitoringEC2.sh", {
    prometheus_config          = file("./monitoring/prometheus/prometheus.yaml")
    prometheus_rules           = file("./monitoring/prometheus/rules.yaml")
    alertmanager_config        = file("./monitoring/alertmanager/alertmanager.yaml")
    grafana_datasource         = file("./monitoring/grafana/provisioning/datasources/datasource.yaml")
    grafana_dashboard_provider = file("./monitoring/grafana/provisioning/dashboards/dashboard.yaml")
    docker_compose             = file("./monitoring/monitoring-compose.yaml")
    monitoring_bucket          = data.terraform_remote_state.network.outputs.monitoring_config_bucket_name
  }))

  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile_monitoring.name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "EC2-monitoring-instance"
  }
}
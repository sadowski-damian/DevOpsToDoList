#!/usr/bin/env bash

# Update all system packages to the latest version before we install anything
sudo dnf update -y

# Install Docker engine
sudo dnf install -y docker

# Start Docker daemon immediately and enable it so it starts automatically after every reboot
sudo systemctl start docker
sudo systemctl enable docker

# Install Docker Compose plugin - it is not available in dnf so we download the binary directly from GitHub
# we place it in the Docker CLI plugins directory so it works as "docker compose" command
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Create directory for Prometheus config files
sudo mkdir -p /etc/prometheus

# Write Prometheus config and alert rules to disk - content is injected by Terraform templatefile at apply time
# tee writes the content to the file, > /dev/null suppresses output in the terminal
sudo tee /etc/prometheus/prometheus.yml > /dev/null << 'EOF'
${prometheus_config}
EOF

sudo tee /etc/prometheus/rules.yaml > /dev/null << 'EOF'
${prometheus_rules}
EOF

# Retrieve Slack webhook URL from SSM - Alertmanager needs it to send alert notifications to our Slack channel
SLACK_WEBHOOK=$(aws ssm get-parameter --name "/prod/slack-webhook-url" --query "Parameter.Value" --output text --with-decryption)

# Create directory for Alertmanager and write its config to disk
# We use regular EOF here (without quotes) so bash can use the $SLACK_WEBHOOK variable into the config
sudo mkdir -p /etc/alertmanager
sudo tee /etc/alertmanager/alertmanager.yaml > /dev/null << EOF
${alertmanager_config}
EOF

# Create all directories Grafana needs for auto-provisioning datasources and dashboards
sudo mkdir -p /etc/grafana/provisioning/datasources
sudo mkdir -p /etc/grafana/provisioning/dashboards
sudo mkdir -p /etc/grafana/dashboards

# Write Grafana provisioning configs to disk - Grafana reads these on startup to configure datasource and dashboard provider automatically
sudo tee /etc/grafana/provisioning/datasources/datasource.yaml > /dev/null << 'EOF'
${grafana_datasource}
EOF

sudo tee /etc/grafana/provisioning/dashboards/dashboard.yaml > /dev/null << 'EOF'
${grafana_dashboard_provider}
EOF

# Download the Node Exporter dashboard JSON from S3 - it was uploaded there by Terraform during infra apply
aws s3 cp s3://${monitoring_bucket}/grafana/node-exporter.json /etc/grafana/dashboards/node-exporter.json

# Replace the datasource placeholder in the dashboard JSON with the actual datasource name we configured in Grafana
sed -i 's/$${DS_PROMETHEUS}/prometheus/g' /etc/grafana/dashboards/node-exporter.json

# Write Docker Compose file to disk - it defines Prometheus, Alertmanager and Grafana containers with their volumes and config mounts
sudo tee /home/ec2-user/docker-compose.yaml > /dev/null << 'EOF'
${docker_compose}
EOF

# Start all monitoring containers in detached mode - this brings up Prometheus, Alertmanager and Grafana
cd /home/ec2-user && sudo docker compose up -d
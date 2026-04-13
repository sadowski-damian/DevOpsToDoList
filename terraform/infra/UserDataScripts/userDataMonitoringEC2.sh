#!/usr/bin/env bash
# System updates
sudo dnf update -y

# Install docker
sudo dnf install -y docker

# Run and make Docker run on every system start
sudo systemctl start docker
sudo systemctl enable docker

# Install docker compose plugin not available in dnf so we download it manually from GitHub
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Creat /etc/prometheus dir as we will be using it to pass our prometheus conf
sudo mkdir -p /etc/prometheus

# tee writes content to file, > /dev/null makes it so we doesnt get output in the terminal
sudo tee /etc/prometheus/prometheus.yml > /dev/null << 'EOF'
${prometheus_config}
EOF

# Same as with prometheus we create directories so we can pass our configuration files
sudo mkdir -p /etc/grafana/provisioning/datasources
sudo mkdir -p /etc/grafana/provisioning/dashboards
sudo mkdir -p /etc/grafana/dashboards

sudo tee /etc/grafana/provisioning/datasources/datasource.yaml > /dev/null << 'EOF'
${grafana_datasource}
EOF

sudo tee /etc/grafana/provisioning/dashboards/dashboard.yaml > /dev/null << 'EOF'
${grafana_dashboard_provider}
EOF

aws s3 cp s3://${monitoring_bucket}/grafana/node-exporter.json /etc/grafana/dashboards/node-exporter.json

# Copy our dockercompose
sudo tee /home/ec2-user/docker-compose.yaml > /dev/null << 'EOF'
${docker_compose}
EOF

# Start prometheus and graphana in detached mode
cd /home/ec2-user && sudo docker compose up -d


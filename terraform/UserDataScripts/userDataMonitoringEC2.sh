#!/usr/bin/env bash
# System updates
sudo dnf update -y

# Install docker
sudo dnf install -y docker

# Run and make Docker run on every system start
sudo systemctl start docker
sudo systemctl enable docker

sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Creat /etc/prometheus dir as we will be using it to pass our prometheus conf
sudo mkdir -p /etc/prometheus
# Passing prometheus conf 
sudo tee /etc/prometheus/prometheus.yml > /dev/null << 'PROMEOF'
${prometheus_config}
PROMEOF

# Same as with prometheus we create directories so we can pass our configuration files
sudo mkdir -p /etc/grafana/provisioning/datasources
sudo mkdir -p /etc/grafana/provisioning/dashboards

sudo tee /etc/grafana/provisioning/datasources/datasource.yaml > /dev/null << 'EOF'
${grafana_datasource}
EOF

sudo tee /etc/grafana/provisioning/dashboards/dashboard.yaml > /dev/null << 'EOF'
${grafana_dashboard_provider}
EOF

# Copy our dockercompose
sudo tee /home/ec2-user/docker-compose.yaml > /dev/null << 'EOF'
${docker_compose}
EOF

# And start 
cd /home/ec2-user && sudo docker compose up -d


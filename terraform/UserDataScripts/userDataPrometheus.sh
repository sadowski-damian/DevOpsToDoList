#!/usr/bin/env bash
# System updates
sudo dnf update -y

# Install docker
sudo dnf install -y docker

# Run and make Docker run on every system start
sudo systemctl start docker
sudo systemctl enable docker

# We create prometheus folder and prometheus.yml file with confiuration
sudo mkdir /etc/prometheus
sudo touch /etc/prometheus/prometheus.yml

# Adding prometheus configuration so it can scrape matrics from our ec2 instances
sudo tee -a /etc/prometheus/prometheus.yml > /dev/null << 'EOF'
scrape_configs:
  - job_name: 'scrape_ec2'
    ec2_sd_configs:
      - region: eu-central-1
        port: 9100
        refresh_interval: 30s
        filters:
          - name: tag:Name
            values: ["EC2-instance-ASG"]
EOF

# Running Docker using prometheus image in detached mode, also we are mounting prometheus.yml file inside container
docker run --name prometheus -d -p 9090:9090 -v /etc/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus
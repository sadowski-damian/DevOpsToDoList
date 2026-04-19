#!/usr/bin/env bash

# Update all system packages to the latest version before we install anything
sudo dnf update -y

# Install Docker engine
sudo dnf install -y docker

# Start Docker daemon immediately and enable it so it starts automatically after every reboot
sudo systemctl start docker
sudo systemctl enable docker

# Retrieve GHCR credentials from SSM Parameter Store - --with-decryption is required because they are stored as SecureString
GHCR_LOGIN=$(aws ssm get-parameter --name "/prod/ghcr-login" --query "Parameter.Value" --output text --with-decryption)
GHCR_PASSWORD=$(aws ssm get-parameter --name "/prod/ghcr-password" --query "Parameter.Value" --output text --with-decryption)

# Log in to GitHub Container Registry so Docker can pull our private application image
echo "$GHCR_PASSWORD" | docker login ghcr.io -u "$GHCR_LOGIN" --password-stdin

# Retrieve the database connection string from SSM - it contains host, port, database name, username and password
DB_CONN=$(aws ssm get-parameter --name "/prod/db-connection-string" --query "Parameter.Value" --output text --with-decryption)

# Retrieve the API key from SSM - it is used by the application to authenticate incoming requests
API_KEY=$(aws ssm get-parameter --name "/prod/api-key" --query "Parameter.Value" --output text --with-decryption)

# Run the application container
# -d runs it in background, --restart=always makes Docker restart it automatically if it crashes or instance reboots
# -p 8080:8080 maps the container port to the host so ALB can reach it
# we pass DB connection string and API key as environment variables so they are never written to disk
docker run -d --restart=always -p 8080:8080 -e ConnectionStrings__Postgres="$DB_CONN" -e ApiKey="$API_KEY" ghcr.io/sadowski-damian/wenttoprod:latest

# Run Node Exporter so Prometheus on the monitoring instance can scrape system metrics from this EC2
# --pid=host and --net=host give it access to host network and process info so it can collect system metrics
# -v /:/host:ro,rslave mounts the host filesystem as read-only so Node Exporter can read disk and filesystem stats
docker run -d --restart=always --pid="host" --net="host" -v "/:/host:ro,rslave" prom/node-exporter --path.rootfs=/host
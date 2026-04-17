#!/usr/bin/env bash
# System updates
sudo dnf update -y

# Install docker
sudo dnf install -y docker

# Run and make Docker run on every system start
sudo systemctl start docker
sudo systemctl enable docker

# Retrieve parameters for further use in logging into GCR.IO and store them in env variable
GHCR_LOGIN=$(aws ssm get-parameter --name "/prod/ghcr-login" --query "Parameter.Value" --output text --with-decryption)
GHCR_PASSWORD=$(aws ssm get-parameter --name "/prod/ghcr-password" --query "Parameter.Value" --output text --with-decryption)

# Login into GHCR 
echo "$GHCR_PASSWORD" | docker login ghcr.io -u "$GHCR_LOGIN" --password-stdin

# Retrieve connection string for postgreSQL
DB_CONN=$(aws ssm get-parameter --name "/prod/db-connection-string" --query "Parameter.Value" --output text --with-decryption)

# Retrieve API key
API_KEY=$(aws ssm get-parameter --name "/prod/api-key" --query "Parameter.Value" --output text --with-decryption)

# Docker run our app
docker run -d --restart=always -p 8080:8080 -e ConnectionStrings__Postgres="$DB_CONN" -e ApiKey="$API_KEY" ghcr.io/sadowski-damian/wenttoprod:latest

# Docker run node-exporter for prometheus
docker run -d --restart=always --pid="host" --net="host" -v "/:/host:ro,rslave" prom/node-exporter --path.rootfs=/host
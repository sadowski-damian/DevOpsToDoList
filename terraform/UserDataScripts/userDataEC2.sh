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
export GHCR_LOGIN

GHCR_PASSWORD=$(aws ssm get-parameter --name "/prod/ghcr-password" --query "Parameter.Value" --output text --with-decryption)
export GHCR_PASSWORD

# Login into GHCR 
echo "$GHCR_PASSWORD" | docker login ghcr.io -u "$GHCR_LOGIN" --password-stdin

# Docker run
docker run -d --restart=always -p 8080:8080 ghcr.io/niemajeszczenamespace/app:latest


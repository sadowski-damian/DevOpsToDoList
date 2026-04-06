#!/usr/bin/env bash
# System updates
sudo dnf update
sudo dnf upgrade

# Install docker
sudo dnf install -y docker

# Run and make Docker run on every system start
sudo systemctl start docker
sudo systemctl enable docker



#!/bin/bash
# Creates an SSM port forwarding to the Grafana instance running in a private subnet
# After running, Grafana will be accessible at this address http://localhost:3000 
# 1. Prerequisites:
#  - Configured aws cli in region eu-central-1 (aws configure)
#  - AWS Session Manager plugin installed
#  - Infra terraform layer deployed (EC2-monitoring-instance has to be running)
# 2. How to use?
#  - ./scripts/grafana-forward.sh

# Saves output to the INSTANCE_ID variable, aws ec2 describe-instances - gets information about ec2 instances
# --filters - gets only instances with tag:Name = EC2-monitoring and instance-state-name = running. So we only get our monitoring instance that is running
# --query - from JSON response takes only ID of first found instance
# --output text - returns output in plain text.
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=EC2-monitoring-instance" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text)
  
# Starts port forwarding session, aws ssm start-session - starts SSM session with instance that has ID from the variable be set earlier
# --document-name - specifies document that supports port forwarding
# --parameters - tunnels port 3000 from EC2 to our local port 3000
aws ssm start-session --target "$INSTANCE_ID" \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}'
  
echo "SSM port forwarding created."


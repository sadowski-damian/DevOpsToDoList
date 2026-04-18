#!/bin/bash
# Creates an SSM port forwarding to the Grafana instance running in a private subnet
# After running, Grafana will be accessible at this address http://localhost:3000 
# 1. Prerequisites:
#  - Configured aws cli in region eu-central-1 (aws configure)
#  - AWS Session Manager plugin installed
#  - Infra terraform layer deployed (EC2-monitoring-instance has to be running)
# 2. How to use?
#  - ./scripts/grafana-forward.sh

INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=EC2-monitoring-instance" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text)
  
aws ssm start-session --target "$INSTANCE_ID" \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}'
  
echo "SSM port forwarding created."


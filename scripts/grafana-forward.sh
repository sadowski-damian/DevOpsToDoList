#!/bin/bash

INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=EC2-monitoring-instance" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text)
aws ssm start-session --target "$INSTANCE_ID" --document-name AWS-StartPortForwardingSession --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}'


#!/bin/bash  
# Puts ssm parameters required for app to work.
# 1. Prerequirements:
#  - Configured aws cli in regions eu-central-1 (aws configure)
#  - Privileges to ssm:PutParameter
# 2. How to use?
#  - ./scripts/bootstrap-ssm.sh [ghcr-login] [ghcr-password] [api-key]
                                                                                                 
aws ssm put-parameter --name "/prod/ghcr-login" --value "$1" --type SecureString --overwrite                                                                            
aws ssm put-parameter --name "/prod/ghcr-password" --value "$2" --type SecureString --overwrite                                                                       
aws ssm put-parameter --name "/prod/api-key" --value "$3" --type SecureString --overwrite
echo "AWS SSM parameters created" 
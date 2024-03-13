#!/bin/bash

# Define AWS credentials and default region
AWS_ACCESS_KEY_ID="YourAccessKeyID"
AWS_SECRET_ACCESS_KEY="YourSecretAccessKey"
AWS_DEFAULT_REGION="us-west-2"

# Install AWS CLI if not already installed
if ! command -v aws &> /dev/null
then
    sudo apt update
    sudo apt install -y awscli
fi

# Create AWS config directory if it doesn't exist
mkdir -p ${HOME}/.aws

# Configure AWS default region and output format
echo -e "[default]\nregion = ${AWS_DEFAULT_REGION}\noutput = text" > ${HOME}/.aws/config

# Configure AWS credentials
echo -e "[default]\naws_access_key_id = $AWS_ACCESS_KEY_ID\naws_secret_access_key = $AWS_SECRET_ACCESS_KEY" > ${HOME}/.aws/credentials

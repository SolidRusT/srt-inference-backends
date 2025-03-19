#!/bin/bash
set -e

# Get input parameters
ECR_REPOSITORY_URL=$1
AWS_REGION=$2
APP_PATH=$3

echo "Building and pushing Docker image to ECR..."
echo "Repository URL: $ECR_REPOSITORY_URL"
echo "AWS Region: $AWS_REGION"
echo "App Path: $APP_PATH"

# Extract repository name from URL (the part after the last /)
REPO_NAME=$(echo $ECR_REPOSITORY_URL | sed 's/.*\///g')

# Get AWS account ID from repository URL (the part after @, before the first period)
ACCOUNT_ID=$(echo $ECR_REPOSITORY_URL | sed 's/.*@\([0-9]*\).*/\1/')
if [ -z "$ACCOUNT_ID" ]; then
  # Alternative method: extract from repository URL domain
  ACCOUNT_ID=$(echo $ECR_REPOSITORY_URL | sed 's/.*\/\([0-9]*\).*/\1/')
fi

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPOSITORY_URL

# Build the Docker image
echo "Building Docker image..."
cd $APP_PATH
docker build -t $REPO_NAME:latest .

# Tag and push the image
echo "Tagging and pushing Docker image to ECR..."
docker tag $REPO_NAME:latest $ECR_REPOSITORY_URL:latest
docker push $ECR_REPOSITORY_URL:latest

echo "Docker image successfully built and pushed to ECR!"

#!/bin/bash

set -e

echo "=== NimbusCart App Deployment ==="

echo "Installing Docker..."

if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y docker awscli
else
    sudo apt-get update
    sudo apt-get install -y docker.io awscli
fi

sudo systemctl enable docker
sudo systemctl start docker

echo "Docker version:"
sudo docker --version

echo "Logging into Amazon ECR..."

aws ecr get-login-password --region ap-south-1 \
  | sudo docker login \
      --username AWS \
      --password-stdin "${ECR_REGISTRY}"

echo "Pulling NimbusCart API image..."

sudo docker pull "${ECR_IMAGE}"

echo "Stopping old container if present..."

sudo docker rm -f nimbuscart-api 2>/dev/null || true

echo "Starting NimbusCart API..."

sudo docker run -d \
  --name nimbuscart-api \
  --restart unless-stopped \
  -p 5000:5000 \
  -e DB_HOST="${DB_HOST}" \
  -e DB_PORT="3306" \
  -e DB_NAME="${DB_NAME}" \
  -e DB_USER="${DB_USER}" \
  -e DB_PASSWORD="${DB_PASSWORD}" \
  "${ECR_IMAGE}"

echo "=== NimbusCart API deployment complete ==="

sudo docker ps

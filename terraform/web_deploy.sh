#!/bin/bash

set -e

echo "=== NimbusCart Web Deployment ==="

echo "Installing Nginx..."

if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y nginx
else
    sudo apt-get update
    sudo apt-get install -y nginx
fi

sudo systemctl enable nginx

sudo mkdir -p /usr/share/nginx/html

echo "Copying frontend..."

sudo cp /tmp/index.html /usr/share/nginx/html/index.html
sudo cp /tmp/nginx.conf /etc/nginx/conf.d/default.conf

echo "Testing Nginx configuration..."

sudo nginx -t

echo "Starting Nginx..."

sudo systemctl restart nginx

echo "=== NimbusCart Web Deployment Complete ==="

sudo systemctl status nginx --no-pager

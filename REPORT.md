# NimbusCart — AWS Three-Tier Application Report

## 1. Project Overview

NimbusCart is a three-tier product-catalog application deployed on AWS using Terraform, Docker, Nginx, EC2, VPC Peering, NAT Gateway, Amazon ECR, and Amazon RDS MySQL.

The Web tier contains Nginx and the static frontend. The App tier contains the Flask REST API in a Docker container. The Data tier contains the private RDS MySQL database.

## 2. Final Architecture

Internet -> Web VPC (10.10.0.0/16) -> VPC Peering -> App VPC (10.20.0.0/16) -> VPC Peering -> Data VPC (10.30.0.0/16)

Web EC2 runs Nginx and serves the frontend. The private App EC2 runs Docker and Flask. RDS MySQL provides the database.

## 3. Frontend

The frontend is located in app/frontend/index.html. It loads products using GET /api/items, displays them in a table, provides an Add Product form, sends POST /api/items requests, refreshes the table after insertion, and displays an error state when an API request fails.

Nginx serves the static frontend and reverse-proxies /api/ requests to the private App EC2.

## 4. REST API

The REST API is implemented using Flask and runs as a single Docker container on the App EC2. The Docker image is built using a Dockerfile and stored in Amazon ECR. The API creates its database schema during startup.

The products table contains id, name, price, and stock.

## 5. Manual VPC Peering Experiment

The VPC peering behavior was tested manually using throwaway networking resources. When the return route was missing, Network Reachability Analyzer reported NetworkPathFound = False with NO_ROUTE_TO_DESTINATION. After the missing return route was added, NetworkPathFound = True. This demonstrated that both directions require appropriate routes for bidirectional communication across VPC peering.

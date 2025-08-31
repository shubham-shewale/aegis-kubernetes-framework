# Kops Configuration

This directory contains kops cluster configuration templates and utilities for managing Kubernetes clusters on AWS.

## Templates

- `cluster.yaml.template`: Base template for kops cluster configuration with multi-AZ setup

## Usage

1. Copy the template to create environment-specific configurations
2. Replace placeholders with actual values
3. Use kops to create/update the cluster

## Placeholders

- `{{CLUSTER_NAME}}`: Full cluster name (e.g., staging.cluster.example.com)
- `{{KOPS_STATE_BUCKET}}`: S3 bucket for kops state
- `{{ENVIRONMENT}}`: Environment name
- `{{REGION}}`: AWS region
- `{{VPC_CIDR}}`: VPC CIDR block
- `{{PUBLIC_SUBNET_1/2/3}}`: Public subnet CIDRs
- `{{PRIVATE_SUBNET_1/2/3}}`: Private subnet CIDRs

## Multi-Cluster Setup

For multi-cluster deployments:
1. Create separate configurations for each cluster
2. Use different S3 state buckets or prefixes
3. Configure cross-cluster networking if needed
# Automation Scripts

This directory contains automation scripts for provisioning and managing Aegis Kubernetes clusters.

## Go Scripts

The `go/` directory contains Go-based automation tools:

- `main.go`: CLI tool for cluster provisioning and management
- `go.mod`: Go module dependencies

## Usage

1. Build the Go CLI:
   ```bash
   cd scripts/go
   go build -o aegis main.go
   ```

2. Provision a cluster:
   ```bash
   export AEGIS_ENVIRONMENT=staging
   export AWS_REGION=us-east-1
   export CLUSTER_NAME=staging.cluster.aegis.local
   export KOPS_STATE_BUCKET=your-state-bucket
   ./aegis provision
   ```

3. Destroy a cluster:
   ```bash
   ./aegis destroy
   ```

## Environment Variables

- `AEGIS_ENVIRONMENT`: Environment name (default: staging)
- `AWS_REGION`: AWS region (default: us-east-1)
- `CLUSTER_NAME`: Full cluster name
- `KOPS_STATE_BUCKET`: S3 bucket for kops state
- `VPC_CIDR`: VPC CIDR block (default: 10.0.0.0/16)

## Prerequisites

- Go 1.21+
- AWS CLI configured
- kops installed
- kubectl installed
- Terraform installed
# Deployment Guide

This guide provides step-by-step instructions for deploying the Aegis Kubernetes Framework.

## Prerequisites

- AWS CLI configured with appropriate permissions
- kubectl installed
- kops installed
- **Terraform >= 1.5.0** (with enhanced validation and security features)
- Go >= 1.21 (for custom scripts)
- Docker (for image building)
- chmod +x for shell scripts

## Quick Start

### 1. Clone and Setup

```bash
git clone https://github.com/your-org/aegis-kubernetes-framework.git
cd aegis-kubernetes-framework
```

### 2. Configure Environment

```bash
export AWS_REGION=us-east-1
export ENVIRONMENT=staging
export CLUSTER_NAME=staging.cluster.aegis.local
export KOPS_STATE_BUCKET=your-kops-state-bucket
```

### 3. Provision Infrastructure

```bash
cd terraform

# Initialize with enhanced backend configuration
# Edit backend.tf with your S3 bucket details before running init
terraform init

# Validate with comprehensive input validation
terraform validate

# Plan with enhanced security and validation
terraform plan

# Apply with improved error handling and dependency management
terraform apply
```

### 4. Build Automation CLI

```bash
cd ../scripts/go
go build -o aegis main.go
```

### 5. Provision Cluster

```bash
./aegis provision
```

### 6. Deploy Security Components

```bash
kubectl apply -f ../../manifests/argocd/install.yaml
kubectl apply -f ../../manifests/istio/
kubectl apply -f ../../manifests/kyverno/
kubectl apply -f ../../manifests/trivy/
```

## Detailed Deployment

### Infrastructure Setup

1. **VPC and Networking** (Enhanced):
   - Creates VPC with public/private subnets across multiple AZs
   - Sets up NAT gateways for outbound traffic with proper dependencies
   - Configures route tables and security groups with consistent tagging
   - Implements proper resource ordering and lifecycle management

2. **IAM Roles** (Security Enhanced):
   - **kops service role with least-privilege custom policy** (replacing dangerous AdministratorAccess)
   - Node instance profiles with minimal required permissions
   - Region-scoped and resource-specific access controls
   - Proper separation of duties and access boundaries

3. **S3 State Store** (Improved):
   - Encrypted bucket for kops cluster state with proper naming
   - Versioning and lifecycle policies enabled
   - Public access blocked with comprehensive security settings
   - Consistent tagging and access logging

### Cluster Provisioning

1. **Generate Cluster Config**:
   ```bash
   cd kops
   # Edit templates/cluster.yaml.template with your values
   # The Go script handles template processing automatically
   ```

2. **Create Cluster**:
   - kops creates EC2 instances
   - Configures Kubernetes control plane
   - Sets up worker nodes

3. **Validate Cluster**:
   ```bash
   kops validate cluster --name $CLUSTER_NAME --wait 10m
   ```

4. **Run Enhanced Validation**:
   ```bash
   # Comprehensive cluster health and security validation
   chmod +x ../scripts/validate-cluster.sh
   ../scripts/validate-cluster.sh

   # Security compliance and policy validation
   chmod +x ../scripts/validate-compliance.sh
   ../scripts/validate-compliance.sh

   # Certificate health and rotation validation
   chmod +x ../scripts/cert-rotation.sh
   ../scripts/cert-rotation.sh --check-all
   ../scripts/cert-rotation.sh --validate
   ```

### Security Setup

1. **ArgoCD Installation**:
   ```bash
   kubectl create namespace argocd
   kubectl apply -f manifests/argocd/install.yaml
   ```

2. **Istio Service Mesh**:
   ```bash
   istioctl install --set profile=demo
   kubectl apply -f manifests/istio/
   ```

3. **Kyverno Policies**:
   ```bash
   kubectl apply -f manifests/kyverno/
   ```

4. **Trivy Scanner**:
   ```bash
   kubectl create namespace trivy-system
   kubectl apply -f manifests/trivy/
   ```

## Post-Deployment Configuration

### ArgoCD Setup

1. Get admin password:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

2. Access ArgoCD UI:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```

3. Login and create applications for GitOps management

### Image Signing Setup

1. Generate Cosign keys:
   ```bash
   chmod +x scripts/cosign-keygen.sh
   ./scripts/cosign-keygen.sh
   ```

2. Update Kyverno policy with your public key

3. Configure CI/CD for automatic signing

## Security Enhancements

The framework includes several critical security improvements:

### 🔐 **IAM Security**
- **Eliminated AdministratorAccess**: Replaced with custom least-privilege policies
- **Region-scoped permissions**: Access limited to specific AWS regions
- **Resource-specific access**: Policies scoped to exact resources needed

### ✅ **Input Validation**
- **Comprehensive validation**: All Terraform variables validated at plan time
- **CIDR validation**: Network ranges validated for correctness
- **Tag validation**: AWS tagging restrictions enforced

### 🏗️ **Infrastructure Security**
- **Consistent tagging**: All resources tagged with project, environment, and purpose
- **Dependency management**: Proper resource ordering prevents race conditions
- **Encryption**: S3 buckets encrypted with proper access controls

### 🔐 **Certificate Management**
- **Automated Certificate Rotation**: Proactive renewal before expiration
- **Certificate Health Monitoring**: Continuous validation and alerting
- **Certificate Authority Integration**: Support for enterprise CAs
- **Certificate Policy Enforcement**: Kyverno policies prevent expired certificates

### 🌐 **Network Policy Security**
- **Default Deny Policies**: All namespaces require explicit network policies
- **DNS Access Control**: Controlled DNS resolution for pods
- **API Server Access**: Restricted communication to Kubernetes API
- **Service Mesh Integration**: Istio policies complement network policies

### 🗄️ **etcd Security Enhancements**
- **etcd Encryption Validation**: Kyverno policies ensure encryption is enabled
- **etcd Access Restrictions**: Prevent direct etcd access from non-system pods
- **etcd Pod Security**: Non-root execution and privilege escalation prevention
- **etcd Network Isolation**: Dedicated network policies for etcd components

## Multi-Cluster Deployment

For production deployments with multiple clusters:

1. Create separate Terraform workspaces or state files
2. Use different S3 buckets for kops state (automatically generated with unique names)
3. Configure cross-cluster networking with proper security groups
4. Set up ArgoCD for multi-cluster management with enhanced RBAC
5. Use the validation scripts to ensure compliance across all clusters

## Troubleshooting

### Common Issues

1. **kops validation fails**:
   - Check AWS permissions
   - Verify VPC/subnet configuration
   - Check security groups

2. **ArgoCD not accessible**:
   - Verify ingress configuration
   - Check TLS certificate setup
   - Confirm DNS resolution

3. **Security policies blocking deployments**:
   - Review Kyverno policy violations
   - Check image signatures
   - Verify pod security contexts

### Logs and Debugging

```bash
# Check cluster status
kops validate cluster --name $CLUSTER_NAME

# Run comprehensive validation
./scripts/validate-cluster.sh
./scripts/validate-compliance.sh

# View ArgoCD logs
kubectl logs -n argocd deployment/argocd-server

# Check Kyverno policy violations
kubectl get policyreports -A

# View Terraform state and resources
cd terraform
terraform state list
terraform show

# Check AWS resources
aws ec2 describe-instances --filters "Name=tag:Project,Values=aegis-kubernetes-framework"
```

## Cleanup

To destroy the cluster and infrastructure:

```bash
./aegis destroy
cd terraform
terraform destroy
```

## Next Steps

- Configure monitoring and logging
- Set up backup and disaster recovery
- Implement CI/CD pipelines
- Configure network policies
- Set up secrets management
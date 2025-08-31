# Aegis Kubernetes Framework

A production-grade, secure-by-default framework for provisioning and managing self-hosted, multi-cluster Kubernetes on AWS using kops.

## Overview

Aegis provides a robust foundation for running secure, resilient, and observable containerized workloads across multiple AWS regions. Built on the principles of **Secure by Default**, **Zero Trust**, and **Defense in Depth**.

## Key Features

- 🔒 **Enhanced Security**: Least-privilege IAM policies, input validation, certificate rotation, and comprehensive security controls
- 🏗️ **Production-Ready**: Validated Terraform modules with proper error handling and dependency management
- 🔄 **GitOps Integration**: ArgoCD-based declarative cluster management with automated reconciliation
- 🛡️ **Zero Trust Architecture**: Mutual TLS, service mesh isolation, network policies, and continuous verification
- 📊 **Comprehensive Monitoring**: Built-in validation scripts, compliance reporting, and certificate management
- 🚀 **CI/CD Ready**: GitHub Actions workflows for automated testing, security scanning, and image signing

## Architecture

- **Foundational Infrastructure**: Enhanced Terraform modules with VPC, subnets, NAT Gateways, IAM roles, and S3 state store
- **Security-First Design**: Input validation, least-privilege policies, and comprehensive tagging strategy
- **Cluster Provisioning**: kops-based Kubernetes cluster configurations with multi-region support
- **Automation & GitOps**: Go-based automation scripts and ArgoCD for declarative cluster management
- **Security Posture**: Istio service mesh, Kyverno policies, Trivy scanning, and Cosign image signing

## Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.5.0
- Go >= 1.21
- kubectl and kops installed

### Basic Setup
1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/aegis-kubernetes-framework.git
   cd aegis-kubernetes-framework
   ```

2. **Configure environment**
   ```bash
   export AWS_REGION=us-east-1
   export ENVIRONMENT=staging
   ```

3. **Initialize Terraform (with improved backend)**
   ```bash
   cd terraform
   # Edit backend.tf with your S3 bucket details
   terraform init
   terraform validate  # Now includes comprehensive input validation
   terraform plan
   terraform apply
   ```

4. **Provision cluster with enhanced security**
   ```bash
   cd ../scripts/go
   go run main.go provision  # Uses least-privilege IAM policies
   ```

5. **Validate deployment**
   ```bash
   ../validate-cluster.sh  # Comprehensive health and security checks
   ../validate-compliance.sh  # Security compliance reporting
   ```

6. **Deploy via GitOps**
   ```bash
   kubectl apply -f ../manifests/argocd/install.yaml
   kubectl apply -f ../manifests/istio/
   kubectl apply -f ../manifests/kyverno/
   ```

## Documentation

- [Deployment Guide](docs/DEPLOYMENT.md) - Step-by-step deployment with security considerations
- [Security Overview](docs/SECURITY.md) - Comprehensive security architecture and controls
- [Architecture Details](docs/ARCHITECTURE.md) - Technical architecture and data flows

## Security & Compliance

Aegis implements enterprise-grade security controls:

### 🔐 **Enhanced Security Features**
- **Least-Privilege IAM**: Custom policies replacing AdministratorAccess
- **Input Validation**: Comprehensive Terraform variable validation
- **Resource Tagging**: Consistent tagging strategy across all resources
- **Dependency Management**: Proper resource ordering and lifecycle management

### ✅ **Compliance & Validation**
- **Automated Validation**: `validate-cluster.sh` for health checks
- **Compliance Reporting**: `validate-compliance.sh` for security audits
- **Policy Enforcement**: Kyverno policies for runtime security
- **Image Security**: Cosign signing with automated validation

### 🛡️ **Zero Trust Implementation**
- **Mutual TLS**: Istio service mesh with automatic encryption
- **Network Policies**: Kubernetes network segmentation
- **Admission Control**: Policy-based resource validation
- **Continuous Monitoring**: Real-time security event detection

## Recent Improvements

### Terraform Code Quality
- ✅ **Critical Security Fix**: Removed AdministratorAccess IAM policy
- ✅ **Input Validation**: Added comprehensive variable validation rules
- ✅ **Backend Configuration**: Resolved chicken-egg problem with dedicated backend.tf
- ✅ **Consistent Tagging**: Implemented standardized resource tagging
- ✅ **Dependency Management**: Added proper resource dependencies and ordering
- ✅ **Provider Enhancement**: Added default tags and version constraints

### Validation & Monitoring
- ✅ **Health Validation**: Comprehensive cluster health checking script
- ✅ **Compliance Auditing**: Automated security compliance reporting
- ✅ **CI/CD Integration**: GitHub Actions for automated testing and security scanning

## Project Status

| Component | Status | Security | Documentation |
|-----------|--------|----------|----------------|
| Terraform Infrastructure | ✅ Production Ready | 🔒 Enhanced | 📚 Comprehensive |
| Kubernetes Clusters | ✅ Multi-Region Support | 🛡️ Zero Trust | 📖 Detailed |
| GitOps Integration | ✅ ArgoCD Ready | 🔄 Automated | 📋 Step-by-Step |
| Security Components | ✅ Enterprise Grade | 🏆 Best Practices | 📊 Auditable |
| CI/CD Pipelines | ✅ Automated | 🔍 Security Scanning | 🤖 Self-Documenting |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to this security-enhanced framework.

## License

MIT License - see [LICENSE](LICENSE) for details.
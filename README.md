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
- 🌐 **Multi-Cluster Support**: East-west gateways with cross-cluster service discovery and federation
- 🔐 **IRSA Integration**: kOps-managed OIDC provider with IAM Roles for Service Accounts
- 📋 **Supply Chain Security**: Kyverno image verification, digest pinning, and attestation validation
- 🏛️ **Internal PKI**: Self-signed CA for private domains with automated certificate management

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

## Security Model

Aegis implements a comprehensive **Secure by Default** architecture following the principles of **Zero Trust**, **Defense in Depth**, and **Least Privilege**.

### 🛡️ **Security Architecture Overview**

#### **1. Identity & Access Management**
- **IRSA (IAM Roles for Service Accounts)**: kOps-managed OIDC provider with least-privilege IAM policies
- **Pod Security Admission (PSA)**: Enforced `restricted` mode by default with documented `baseline` exceptions
- **RBAC**: Scoped role-based access control with ArgoCD OIDC integration

#### **2. Network Security**
- **Zero Trust Networking**: Default-deny NetworkPolicies with explicit allow rules
- **Mutual TLS**: Istio STRICT mTLS with client certificate validation
- **East-West Security**: Dedicated gateways for cross-cluster communication
- **Service Mesh Isolation**: Istio-based traffic encryption and authorization

#### **3. Certificate Management**
- **Internal CA**: Self-signed root CA with cert-manager for private `.local` domains
- **Automated Rotation**: Certificate lifecycle management with monitoring
- **Client Authentication**: Mutual TLS with client certificate validation

#### **4. Supply Chain Security**
- **Image Signing**: Cosign-based signature verification with attestations
- **Registry Allowlisting**: Approved registries with digest pinning
- **Continuous Scanning**: Trivy Operator for vulnerability assessment
- **SBOM Integration**: Software Bill of Materials for dependency tracking

#### **5. Runtime Security**
- **Admission Control**: Kyverno policies for resource validation
- **Privilege Escalation Prevention**: Security contexts and capability restrictions
- **Resource Limits**: Mandatory CPU/memory limits and requests
- **Host Protection**: Restricted hostPath volumes and privileged access

#### **6. Infrastructure Security**
- **Control Plane Encryption**: etcd volume encryption and Kubernetes Secrets encryption at rest
- **Node Hardening**: kOps-managed instance profiles with minimal permissions
- **Network Segmentation**: VPC isolation with security groups and NACLs

### 📋 **Runbooks**

#### **Certificate Management**
```bash
# Check certificate expiry
kubectl get certificates -A

# Renew certificates
kubectl cert-manager renew <certificate-name>

# Validate TLS connections
./scripts/tls-validation.sh
```

#### **IRSA Troubleshooting**
```bash
# Verify OIDC provider
aws iam get-open-id-connect-provider --open-id-connect-provider-arn <oidc-arn>

# Check service account annotations
kubectl get serviceaccount <sa-name> -o yaml

# Test role assumption
kubectl run test-pod --image=amazonlinux:2 --serviceaccount=<sa-name>
```

#### **Network Policy Validation**
```bash
# Check applied policies
kubectl get networkpolicies -A

# Test connectivity
kubectl run test-pod --image=busybox --rm -it -- wget <service-url>
```

#### **Security Incident Response**
```bash
# Check Kyverno policy violations
kubectl get policyreports -A

# Review Trivy scan results
kubectl get vulnerabilityreports -A

# Audit logs
kubectl logs -n kyverno <kyverno-pod>
```

### ✅ **Compliance Validation**

#### **Automated Checks**
```bash
# Full cluster validation
./scripts/validate-cluster.sh

# Kyverno policy tests
kubectl apply -f tests/kyverno-test.yaml

# TLS validation
kubectl apply -f manifests/tests/tls-validation-job.yaml
```

#### **Manual Verification**
- [ ] PSA labels applied to all namespaces
- [ ] NetworkPolicies block unauthorized traffic
- [ ] Certificates use internal CA for .local domains
- [ ] Images pinned by digest with signatures
- [ ] IRSA roles assume correctly
- [ ] ArgoCD uses OIDC authentication
- [ ] etcd encryption enabled
- [ ] Kubernetes Secrets encrypted at rest

### 🔒 **Security Controls Matrix**

| Control Category | Implementation | Validation |
|------------------|----------------|------------|
| **Identity** | IRSA + OIDC | Service account tests |
| **Network** | NetworkPolicies + mTLS | Connectivity tests |
| **Certificates** | Internal CA + cert-manager | TLS validation |
| **Images** | Digest pinning + signatures | Kyverno policies |
| **Runtime** | PSA + Kyverno | Policy reports |
| **Infrastructure** | etcd + K8s encryption | Cluster validation |

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
| **Core Infrastructure** | | | |
| Terraform Infrastructure | ✅ Production Ready | 🔒 Enhanced | 📚 Comprehensive |
| Kubernetes Clusters (kOps) | ✅ Multi-Region Support | 🛡️ Zero Trust | 📖 Detailed |
| **Security Components** | | | |
| Pod Security Admission | ✅ Restricted by Default | 🛡️ PSS Compliance | 📋 Policy Guide |
| Network Policies | ✅ Default Deny | 🔒 Micro-Segmentation | 📋 Implementation |
| Certificate Management | ✅ Internal CA + Mutual TLS | 🔐 PKI Security | 📋 Certificate Guide |
| **Service Mesh & Multi-Cluster** | | | |
| Istio Service Mesh | ✅ STRICT mTLS | 🛡️ Zero Trust | 📖 Configuration |
| East-West Gateways | ✅ Cross-Cluster Federation | 🌐 Multi-Cluster | 📋 Federation Guide |
| **Identity & Access** | | | |
| IRSA (kOps OIDC) | ✅ IAM Roles for SAs | 🔑 Least Privilege | 📋 IRSA Setup |
| ArgoCD Integration | ✅ OIDC SSO + RBAC | 🔐 Secure Access | 📋 GitOps Security |
| **Supply Chain Security** | | | |
| Kyverno Policies | ✅ Image Verification | 🔍 Supply Chain | 📋 Policy Reference |
| Trivy Integration | ✅ Continuous Scanning | 🛡️ Vulnerability Mgmt | 📋 Scanning Guide |
| **Validation & Compliance** | | | |
| Automated Testing | ✅ TLS + Policy Validation | ✅ Compliance | 📋 Test Suite |
| CI/CD Pipelines | ✅ Security Scanning | 🔍 Automated | 🤖 Pipeline Docs |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to this security-enhanced framework.

## License

MIT License - see [LICENSE](LICENSE) for details.
# Aegis Kubernetes Framework - Project Structure

This document provides a comprehensive overview of the Aegis Kubernetes Framework project structure, explaining the purpose and contents of each directory and file.

## 📁 **Root Directory Structure**

```
aegis-kubernetes-framework/
├── .gitignore                 # Git ignore rules
├── .github/                   # GitHub configuration
│   └── workflows/            # CI/CD pipelines
├── CONTRIBUTING.md           # Contribution guidelines
├── LICENSE                   # MIT license
├── README.md                 # Main project documentation
├── docs/                     # Comprehensive documentation
├── examples/                 # Implementation examples
├── kops/                     # Kubernetes cluster configurations
├── manifests/                # Kubernetes manifests
├── scripts/                  # Automation scripts
└── terraform/               # Infrastructure as Code
```

## 📋 **Directory Details**

### **📁 .github/workflows/** - CI/CD Pipelines

**Purpose**: Contains GitHub Actions workflows for automated testing, validation, and deployment.

**Files**:
- `terraform.yml` - Infrastructure validation and planning
- `go.yml` - Go code testing, linting, and security scanning
- `sign-images.yml` - Container image signing and verification
- `security.yml` - Security scanning and compliance checks

**Usage**:
```bash
# Workflows run automatically on:
# - Push to main/develop branches
# - Pull requests
# - Manual triggers
```

### **📁 docs/** - Documentation

**Purpose**: Comprehensive documentation for all aspects of the framework.

**Files**:
- `README.md` - Documentation index and navigation
- `DEPLOYMENT.md` - Step-by-step deployment guide
- `ARCHITECTURE.md` - System architecture and design
- `SECURITY.md` - Security implementation and best practices
- `PROJECT-STRUCTURE.md` - This file

**Organization**:
```
docs/
├── README.md              # Index and navigation
├── DEPLOYMENT.md          # Deployment procedures
├── ARCHITECTURE.md        # System design
├── SECURITY.md           # Security guide
└── PROJECT-STRUCTURE.md  # This overview
```

### **📁 examples/** - Implementation Examples

**Purpose**: Production-ready examples demonstrating framework capabilities.

**Structure**:
```
examples/
├── irsa-implementation/       # IAM Roles for Service Accounts
│   ├── README.md
│   ├── terraform/            # Infrastructure setup
│   ├── manifests/            # Kubernetes resources
│   ├── scripts/              # Automation scripts
│   └── docs/                 # Implementation guide
└── cross-cluster-communication/  # Multi-cluster setup
```

**Key Examples**:
- **IRSA Implementation**: Complete IAM roles for service accounts setup
- **Cross-Cluster Communication**: Service mesh federation example

### **📁 kops/** - Kubernetes Cluster Configuration

**Purpose**: kops-based Kubernetes cluster configurations and templates.

**Structure**:
```
kops/
├── README.md
├── templates/
│   └── cluster.yaml.template    # Cluster configuration template
└── configs/                    # Generated configurations
```

**Contents**:
- Cluster templates with security hardening
- Multi-AZ control plane configuration
- etcd encryption and backup settings
- Network policies and security contexts

### **📁 manifests/** - Kubernetes Manifests

**Purpose**: Declarative Kubernetes resource definitions.

**Structure**:
```
manifests/
├── README.md
├── argocd/                    # GitOps setup
├── istio/                     # Service mesh
├── kyverno/                   # Policy engine
├── trivy/                     # Security scanning
└── security/                  # Security components
```

**Components**:
- **ArgoCD**: GitOps continuous deployment
- **Istio**: Service mesh for zero trust networking
- **Kyverno**: Policy-based security enforcement
- **Trivy**: Container image vulnerability scanning

### **📁 scripts/** - Automation Scripts

**Purpose**: Automation tools for deployment and management.

**Structure**:
```
scripts/
├── README.md
├── go/                        # Go-based CLI tools
│   ├── main.go               # Main CLI application
│   ├── go.mod               # Go module definition
│   └── go.sum               # Dependency checksums
└── cosign-keygen.sh         # Certificate key generation
```

**Tools**:
- **Go CLI**: Cluster provisioning and management
- **Key Generation**: Certificate and signing key management
- **Automation Scripts**: Deployment and configuration helpers

### **📁 terraform/** - Infrastructure as Code

**Purpose**: AWS infrastructure provisioning and management.

**Structure**:
```
terraform/
├── main.tf                   # Main infrastructure
├── variables.tf             # Input variables
├── outputs.tf               # Output values
├── terraform.tfvars        # Variable values
├── providers.tf            # Provider configuration
└── modules/                 # Reusable modules
    ├── vpc/                 # VPC and networking
    ├── iam/                 # Identity and access
    ├── s3/                  # Object storage
    └── security/            # Security components
```

**Modules**:
- **VPC Module**: Network infrastructure with security zones
- **IAM Module**: Roles and policies with least privilege
- **S3 Module**: Encrypted storage for state and backups
- **Security Module**: WAF, GuardDuty, and security services

## 📄 **Key Files Overview**

### **Root Level Files**

| File | Purpose | Key Content |
|------|---------|-------------|
| `README.md` | Project overview | Getting started, architecture, examples |
| `CONTRIBUTING.md` | Contribution guide | Development setup, coding standards, PR process |
| `LICENSE` | Legal license | MIT license terms |
| `.gitignore` | Git exclusions | Build artifacts, secrets, temp files |

### **Configuration Files**

| File | Purpose | Location |
|------|---------|----------|
| `go.mod` | Go dependencies | `scripts/go/go.mod` |
| `terraform.tfvars` | Infrastructure variables | `terraform/terraform.tfvars` |
| `cluster.yaml.template` | K8s cluster template | `kops/templates/cluster.yaml.template` |

## 🔧 **Development Workflow**

### **1. Local Development**
```bash
# Clone repository
git clone https://github.com/org/aegis-kubernetes-framework.git
cd aegis-kubernetes-framework

# Setup development environment
make setup-dev

# Run tests
make test

# Build CLI
cd scripts/go && go build
```

### **2. Infrastructure Development**
```bash
# Navigate to terraform
cd terraform

# Initialize
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply
```

### **3. Kubernetes Development**
```bash
# Deploy manifests
kubectl apply -f manifests/

# Test deployments
kubectl get pods -A

# Check logs
kubectl logs -n argocd deployment/argocd-server
```

## 🧪 **Testing Structure**

### **Unit Tests**
```bash
# Go unit tests
cd scripts/go
go test -v ./...

# Terraform validation
cd terraform
terraform validate
```

### **Integration Tests**
```bash
# End-to-end testing
make test-integration

# Security testing
make security-scan
```

### **CI/CD Testing**
- GitHub Actions workflows run automatically
- Terraform validation on infrastructure changes
- Go testing and linting on code changes
- Security scanning on all changes

## 🔒 **Security Structure**

### **Code Security**
- **Go Security**: gosec scanning in CI/CD
- **Dependency Scanning**: Trivy for vulnerabilities
- **Secret Detection**: GitGuardian for secrets
- **Code Quality**: golangci-lint for code standards

### **Infrastructure Security**
- **Terraform Security**: Checkov scanning
- **IAM Policies**: Least privilege principles
- **Network Security**: Security groups and NACLs
- **Encryption**: KMS for data at rest

### **Container Security**
- **Image Signing**: Cosign for image integrity
- **Vulnerability Scanning**: Trivy for CVEs
- **Policy Enforcement**: Kyverno for admission control
- **Runtime Security**: Falco for threat detection

## 📊 **Monitoring and Observability**

### **Application Monitoring**
- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards
- **AlertManager**: Alert management
- **Logging**: Centralized log aggregation

### **Infrastructure Monitoring**
- **CloudWatch**: AWS service monitoring
- **CloudTrail**: API activity auditing
- **Config**: Configuration compliance
- **GuardDuty**: Threat detection

## 🚀 **Deployment Structure**

### **Environment Separation**
```
├── terraform/
│   ├── environments/
│   │   ├── dev/          # Development environment
│   │   ├── staging/      # Staging environment
│   │   └── prod/         # Production environment
```

### **Multi-Cluster Support**
```
├── kops/
│   ├── clusters/
│   │   ├── us-east-1/    # Region-specific clusters
│   │   └── eu-west-1/
```

### **GitOps Structure**
```
├── manifests/
│   ├── base/             # Common configurations
│   ├── overlays/         # Environment-specific overrides
│   └── applications/     # Application deployments
```

## 📚 **Documentation Access**

### **Quick Reference**
- **Getting Started**: `README.md`
- **Deployment**: `docs/DEPLOYMENT.md`
- **Architecture**: `docs/ARCHITECTURE.md`
- **Security**: `docs/SECURITY.md`
- **Examples**: `examples/*/README.md`

### **Code Documentation**
- **Go Docs**: Inline code documentation
- **Terraform Docs**: Variable and resource documentation
- **YAML Comments**: Manifest explanations
- **Script Headers**: Automation script documentation

## 🔄 **Maintenance and Updates**

### **Regular Maintenance**
- **Dependency Updates**: Go modules and Terraform providers
- **Security Patches**: Container images and system packages
- **Documentation Updates**: Keep docs current with code changes
- **Test Updates**: Update tests for new features

### **Version Management**
- **Semantic Versioning**: Major.Minor.Patch
- **Changelog**: Document changes in each release
- **Backwards Compatibility**: Maintain compatibility where possible
- **Deprecation Notices**: Warn about deprecated features

## 🎯 **Best Practices**

### **Code Organization**
- **Modular Structure**: Separate concerns into modules
- **Consistent Naming**: Follow naming conventions
- **Documentation**: Document all public interfaces
- **Testing**: Comprehensive test coverage

### **Security First**
- **Defense in Depth**: Multiple security layers
- **Least Privilege**: Minimal required permissions
- **Secure Defaults**: Security enabled by default
- **Regular Audits**: Security code reviews

### **Operational Excellence**
- **Automation**: Automate repetitive tasks
- **Monitoring**: Comprehensive observability
- **Documentation**: Clear and current docs
- **Testing**: Automated testing pipelines

## 📞 **Support and Help**

### **Getting Help**
- **Documentation**: Check docs/ directory first
- **Examples**: Review examples/ for patterns
- **Issues**: Search existing GitHub issues
- **Discussions**: Use GitHub Discussions for questions

### **Contributing**
- **Guidelines**: See `CONTRIBUTING.md`
- **Code Standards**: Follow established patterns
- **Testing**: Add tests for new features
- **Documentation**: Update docs for changes

## 🎉 **Conclusion**

The Aegis Kubernetes Framework follows a **well-organized, modular structure** that separates concerns while maintaining **security, scalability, and maintainability**. Each directory serves a specific purpose and contains comprehensive documentation and examples.

**Key Benefits**:
- ✅ **Clear Organization**: Logical separation of concerns
- ✅ **Comprehensive Documentation**: Detailed guides and examples
- ✅ **Security First**: Security built into every component
- ✅ **Modular Design**: Reusable components and patterns
- ✅ **Production Ready**: Enterprise-grade implementations
- ✅ **Community Friendly**: Clear contribution guidelines

This structure ensures that developers, operators, and security teams can **quickly understand, deploy, and maintain** secure Kubernetes infrastructure using the Aegis framework.

**Happy deploying! 🚀🔒**
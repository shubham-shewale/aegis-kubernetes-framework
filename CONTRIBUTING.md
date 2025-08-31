# Contributing to Aegis Kubernetes Framework

Thank you for your interest in contributing to the **Aegis Kubernetes Framework**! This document provides guidelines and information for contributors.

## 📋 **Table of Contents**

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contribution Guidelines](#contribution-guidelines)
- [Documentation Standards](#documentation-standards)
- [Testing](#testing)
- [Security Considerations](#security-considerations)
- [Pull Request Process](#pull-request-process)
- [Community](#community)

## 🤝 **Code of Conduct**

This project follows a code of conduct to ensure a welcoming environment for all contributors. By participating, you agree to:

- **Be respectful** and inclusive in all interactions
- **Focus on constructive feedback** and collaboration
- **Respect differing viewpoints** and experiences
- **Show empathy** towards other community members
- **Gracefully accept** constructive criticism
- **Help create** a positive community environment

## 🚀 **Getting Started**

### **Prerequisites**
- Go 1.21 or later
- Terraform 1.0 or later
- kubectl configured for a Kubernetes cluster
- AWS CLI configured with appropriate permissions
- Git

### **Fork and Clone**
```bash
# Fork the repository on GitHub
# Then clone your fork
git clone https://github.com/your-username/aegis-kubernetes-framework.git
cd aegis-kubernetes-framework

# Add upstream remote
git remote add upstream https://github.com/original-org/aegis-kubernetes-framework.git

# Create a feature branch
git checkout -b feature/your-feature-name
```

## 🛠️ **Development Setup**

### **Local Development Environment**

1. **Install Dependencies**
```bash
# Install Go dependencies
cd scripts/go
go mod download

# Install Terraform
# Follow: https://developer.hashicorp.com/terraform/downloads

# Install kubectl
# Follow: https://kubernetes.io/docs/tasks/tools/

# Install kops
# Follow: https://kops.sigs.k8s.io/getting_started/install/
```

2. **Configure AWS**
```bash
# Configure AWS CLI
aws configure

# Verify configuration
aws sts get-caller-identity
```

3. **Setup Local Kubernetes (Optional)**
```bash
# Using kind for local development
kind create cluster --name aegis-dev

# Or using minikube
minikube start
```

### **Development Workflow**

```bash
# 1. Create feature branch
git checkout -b feature/your-feature

# 2. Make changes
# Edit files, add features, fix bugs

# 3. Run tests
make test

# 4. Format code
make fmt

# 5. Lint code
make lint

# 6. Commit changes
git add .
git commit -m "feat: add your feature description"

# 7. Push to your fork
git push origin feature/your-feature

# 8. Create Pull Request
# Go to GitHub and create a PR
```

## 📝 **Contribution Guidelines**

### **Types of Contributions**

#### **🐛 Bug Fixes**
- Fix security vulnerabilities
- Fix functional bugs
- Fix documentation errors
- Improve error handling

#### **✨ Features**
- New security features
- Infrastructure improvements
- Automation enhancements
- Documentation improvements

#### **📚 Documentation**
- Improve existing documentation
- Add new documentation
- Fix documentation errors
- Create tutorials and guides

#### **🧪 Testing**
- Add unit tests
- Add integration tests
- Improve test coverage
- Add security tests

### **Code Standards**

#### **Go Code**
```go
// Use proper package naming
package main

// Use descriptive variable names
var clusterName string

// Add comments for exported functions
// ValidateClusterConfiguration validates the cluster configuration
func ValidateClusterConfiguration(config *ClusterConfig) error {
    // Implementation
}

// Use proper error handling
if err != nil {
    return fmt.Errorf("failed to validate cluster: %w", err)
}
```

#### **Terraform Code**
```hcl
# Use consistent naming
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Use locals for complex expressions
locals {
  vpc_name = "${var.environment}-vpc"
}

# Use data sources appropriately
data "aws_caller_identity" "current" {}
```

#### **YAML/Kubernetes Manifests**
```yaml
# Use consistent formatting
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: production
  labels:
    app: my-app
    version: v1.0.0
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
        version: v1.0.0
    spec:
      containers:
      - name: app
        image: my-app:v1.0.0
        ports:
        - containerPort: 8080
```

### **Commit Message Standards**

Follow conventional commit format:

```bash
# Feature commits
feat: add IRSA support for service accounts
feat(security): implement Kyverno policies for pod security

# Bug fixes
fix: resolve certificate renewal issue
fix(terraform): fix VPC subnet calculation

# Documentation
docs: update deployment guide for multi-region setup
docs(security): add certificate management section

# Testing
test: add unit tests for IAM role creation
test(integration): add end-to-end security validation

# Breaking changes
feat!: migrate to Terraform 1.0 (breaking change)
```

## 📚 **Documentation Standards**

### **README Files**
- Include clear description and purpose
- Provide installation and usage instructions
- Include examples and code snippets
- Add troubleshooting section
- Link to related documentation

### **Code Documentation**
```go
// Package main provides the CLI interface for Aegis framework
package main

// ClusterConfig holds the configuration for a Kubernetes cluster
type ClusterConfig struct {
    Name      string `json:"name" yaml:"name"`
    Region    string `json:"region" yaml:"region"`
    Version   string `json:"version" yaml:"version"`
    NodeCount int    `json:"nodeCount" yaml:"nodeCount"`
}

// NewClusterConfig creates a new cluster configuration with defaults
func NewClusterConfig(name string) *ClusterConfig {
    return &ClusterConfig{
        Name:      name,
        Region:    "us-east-1",
        Version:   "1.28.0",
        NodeCount: 3,
    }
}
```

### **Terraform Documentation**
```hcl
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block"
  }
}

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}
```

## 🧪 **Testing**

### **Unit Tests**
```go
package main

import (
    "testing"
    "github.com/stretchr/testify/assert"
)

func TestValidateClusterConfig(t *testing.T) {
    config := &ClusterConfig{
        Name:      "test-cluster",
        Region:    "us-east-1",
        Version:   "1.28.0",
        NodeCount: 3,
    }

    err := ValidateClusterConfig(config)
    assert.NoError(t, err)
}

func TestValidateClusterConfig_InvalidName(t *testing.T) {
    config := &ClusterConfig{
        Name:      "",
        Region:    "us-east-1",
        Version:   "1.28.0",
        NodeCount: 3,
    }

    err := ValidateClusterConfig(config)
    assert.Error(t, err)
    assert.Contains(t, err.Error(), "cluster name cannot be empty")
}
```

### **Integration Tests**
```bash
# Run integration tests
make test-integration

# Test specific components
make test-terraform
make test-kubernetes
make test-security
```

### **Security Testing**
```bash
# Run security scans
make security-scan

# Check for vulnerabilities
trivy config .
trivy fs .

# Run Go security checks
gosec ./...
```

## 🔒 **Security Considerations**

### **Security Requirements for Contributions**

#### **1. No Hardcoded Secrets**
```go
// ❌ Bad - hardcoded secret
password := "super-secret-password"

// ✅ Good - use environment variables or config
password := os.Getenv("DATABASE_PASSWORD")
```

#### **2. Input Validation**
```go
// ✅ Validate all inputs
func CreateCluster(name string) error {
    if name == "" {
        return errors.New("cluster name cannot be empty")
    }
    if len(name) > 50 {
        return errors.New("cluster name too long")
    }
    // Additional validation...
}
```

#### **3. Secure Defaults**
```hcl
# ✅ Secure defaults
variable "enable_encryption" {
  description = "Enable encryption at rest"
  type        = bool
  default     = true  # Secure by default
}

variable "public_access" {
  description = "Allow public access"
  type        = bool
  default     = false  # Deny by default
}
```

#### **4. Least Privilege**
```hcl
# ✅ Minimal required permissions
resource "aws_iam_role_policy" "ec2_minimal" {
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceVpc": aws_vpc.main.id
          }
        }
      }
    ]
  })
}
```

## 🔄 **Pull Request Process**

### **Before Submitting**

1. **Update Documentation**
   - Update relevant documentation
   - Add examples if needed
   - Update README if required

2. **Run Tests**
   ```bash
   make test
   make test-integration
   make security-scan
   ```

3. **Format Code**
   ```bash
   make fmt
   make lint
   ```

4. **Security Review**
   - Ensure no secrets are committed
   - Verify security best practices
   - Check for vulnerabilities

### **Submitting a Pull Request**

1. **Create PR from Feature Branch**
   - Ensure branch is up to date with main
   - Write clear PR description
   - Reference related issues

2. **PR Template**
   ```markdown
   ## Description
   Brief description of the changes

   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Documentation update
   - [ ] Security enhancement

   ## Testing
   - [ ] Unit tests pass
   - [ ] Integration tests pass
   - [ ] Security scan passes
   - [ ] Manual testing completed

   ## Security Impact
   - [ ] No security impact
   - [ ] Security enhancement
   - [ ] Requires security review

   ## Checklist
   - [ ] Code follows style guidelines
   - [ ] Documentation updated
   - [ ] Tests added/updated
   - [ ] Security review completed
   ```

3. **PR Review Process**
   - Automated checks must pass
   - At least one maintainer review required
   - Security review for security-related changes
   - Documentation review for docs changes

### **After Merge**
- Delete feature branch
- Update any related issues
- Monitor for any issues in production

## 🌐 **Community**

### **Communication Channels**
- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and discussions
- **Security Issues**: security@aegis-framework.com (private)

### **Getting Help**
- **Documentation**: Check docs/ directory first
- **Examples**: Review examples/ for implementation patterns
- **Issues**: Search existing issues before creating new ones
- **Discussions**: Use GitHub Discussions for questions

### **Community Guidelines**
- **Be Respectful**: Treat all community members with respect
- **Help Others**: Share knowledge and help fellow contributors
- **Stay On Topic**: Keep discussions relevant to the project
- **Follow Guidelines**: Adhere to contribution and code of conduct guidelines

## 🎯 **Recognition**

Contributors are recognized through:
- **GitHub Contributors**: Listed in repository contributors
- **Changelog**: Mentioned in release changelogs
- **Community Recognition**: Special mentions for significant contributions
- **Maintainer Status**: Top contributors may be invited to become maintainers

## 📞 **Support**

### **For Contributors**
- **Technical Questions**: Use GitHub Discussions
- **Code Review**: Request reviews on pull requests
- **Architecture Decisions**: Discuss in GitHub Issues
- **Security Concerns**: Contact maintainers privately

### **For Maintainers**
- **Review Guidelines**: Follow established review processes
- **Mentorship**: Help new contributors get started
- **Community Building**: Foster positive community environment
- **Project Direction**: Guide project roadmap and priorities

## 🙏 **Thank You**

Thank you for contributing to the Aegis Kubernetes Framework! Your contributions help make Kubernetes deployments more secure and manageable for organizations worldwide.

**Happy contributing! 🚀🔒**

---

*For questions or help getting started, please create an issue or start a discussion on GitHub.*
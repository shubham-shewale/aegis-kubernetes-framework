# Aegis Kubernetes Framework - Test Suite

This directory contains comprehensive test cases for all components of the Aegis Kubernetes Framework.

## Test Structure

```
tests/
├── README.md                    # This file
├── vpc/                        # VPC Module Tests
│   ├── unit/                   # Unit tests for VPC logic
│   ├── integration/            # Integration tests for VPC
│   ├── security/               # Security tests for VPC
│   └── compliance/             # Compliance tests for VPC
├── iam/                        # IAM Module Tests
├── s3/                         # S3 Module Tests
├── kops/                       # kOps Cluster Tests
├── kyverno/                    # Kyverno Policy Tests
├── network-policies/           # Network Policy Tests
├── cert-manager/               # Certificate Management Tests
├── istio/                      # Istio Service Mesh Tests
├── argocd/                     # ArgoCD Tests
├── scripts/                    # Validation Scripts Tests
├── ci-cd/                      # CI/CD Pipeline Tests
└── kyverno-test.yaml          # Existing Kyverno test file
```

## Test Categories

### Unit Tests
- Focus on individual component logic
- Fast execution, no external dependencies
- Validate algorithms, calculations, and parsing

### Integration Tests
- Test component interactions
- Validate end-to-end workflows
- Require test environments

### Security Tests
- Validate security controls and configurations
- Test vulnerability scenarios
- Ensure security best practices

### Compliance Tests
- Validate against security frameworks (CIS, NIST, ISO)
- Ensure regulatory compliance
- Generate compliance reports

## Running Tests

### Prerequisites
- Go 1.21+
- Terraform 1.5+
- kubectl configured
- AWS CLI configured

### Execute Tests
```bash
# Run all tests
make test

# Run specific test category
make test-unit
make test-integration
make test-security
make test-compliance

# Run component-specific tests
make test-vpc
make test-iam
make test-kops
```

## Test Frameworks Used

- **Terratest**: Infrastructure testing
- **Go testing**: Unit and integration tests
- **Kyverno CLI**: Policy testing
- **kubetest**: Kubernetes testing
- **Shell scripts**: Validation testing

## Test Environments

### Local Development
- Use kind/minikube for Kubernetes testing
- LocalStack for AWS service mocking
- Docker containers for isolated testing

### CI/CD Environment
- GitHub Actions runners
- Ephemeral test clusters
- Isolated AWS accounts for testing

## Test Coverage Goals

- **Unit Tests**: >90% code coverage
- **Integration Tests**: All critical paths covered
- **Security Tests**: Zero critical vulnerabilities
- **Compliance Tests**: 100% framework compliance

## Contributing Tests

1. Follow the established test structure
2. Include both positive and negative test cases
3. Add appropriate test data and fixtures
4. Document test prerequisites and setup
5. Update this README with new test categories

## Test Reports

Test results are generated in multiple formats:
- JUnit XML for CI/CD integration
- HTML reports for human readability
- JSON reports for automated processing
- Compliance reports for audit purposes

## Security Testing

Security tests include:
- Vulnerability scanning
- Configuration validation
- Access control verification
- Encryption validation
- Compliance checking

## Performance Testing

Performance tests measure:
- Infrastructure provisioning time
- Application deployment time
- Resource utilization
- Scalability limits
- Recovery time objectives

## Chaos Testing

Chaos tests validate:
- System resilience
- Failure recovery
- High availability
- Disaster recovery procedures

---

*Test Suite Version: 2.0.0*
*Last Updated: 2024-01-01*
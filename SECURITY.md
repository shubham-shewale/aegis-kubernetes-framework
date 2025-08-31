# Security Architecture

## Overview

Aegis implements a comprehensive security architecture based on the principles of **Secure by Default**, **Zero Trust**, and **Defense in Depth**. This document outlines the security controls, implementation details, and validation procedures.

## Security Principles

### Secure by Default
- All components start in a secure state
- Security controls are enabled by default
- Exceptions require explicit justification and documentation

### Zero Trust
- Never trust, always verify
- Mutual TLS for all service communication
- Identity-based authorization for all access

### Defense in Depth
- Multiple layers of security controls
- No single point of failure
- Compensating controls for layered protection

## Security Controls

### 1. Identity & Access Management

#### IRSA (IAM Roles for Service Accounts)
- **Implementation**: kOps-managed OIDC provider with `serviceAccountIssuerDiscovery` enabled
- **Scope**: Service accounts assume IAM roles without storing credentials
- **Validation**: Automated tests verify role assumption and permission boundaries
- **Configuration**: OIDC discovery store in S3 with `enableAWSOIDCProvider: true`

```yaml
# Service Account with IRSA annotation
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-access-sa
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/s3-access-role
```

#### Pod Security Admission (PSA)
- **Enforce Level**: `restricted` by default
- **Audit Level**: `restricted` for monitoring
- **Warn Level**: `restricted` for development feedback

```yaml
# Namespace with PSA labels
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.28
```

### 2. Network Security

#### Network Policies
- **Default Policy**: Deny all traffic by default
- **Explicit Allows**: Only documented destinations permitted
- **Namespace Isolation**: Traffic restricted to required namespaces

```yaml
# Default deny policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

#### Mutual TLS
- **Mode**: STRICT for all service communication
- **Certificate Authority**: Internal CA for private domains
- **Client Validation**: Certificate-based client authentication

```yaml
# Peer Authentication
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: global-mtls-strict
spec:
  mtls:
    mode: STRICT
```

### 3. Certificate Management

#### Internal Certificate Authority
- **Root CA**: Self-signed with cert-manager ClusterIssuer
- **Issuers**: `internal-ca-issuer` for private `.local` domains
- **Domains**: All `.local` and internal domains use internal CA
- **Mutual TLS**: Gateway client certificate validation with `ca.crt`
- **Validation**: TLS tests use `--cacert` instead of `-k` bypass

```yaml
# Internal CA Certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: internal-root-ca
spec:
  secretName: internal-root-ca-cert
  isCA: true
  issuerRef:
    name: internal-root-ca-issuer
    kind: Issuer
```

#### Certificate Validation
- **TLS Verification**: All connections validate certificates
- **Client Certificates**: Mutual TLS with client authentication
- **Monitoring**: Certificate expiry alerts and automated renewal

### 4. Supply Chain Security

#### Image Security
- **Digest Pinning**: `mutateDigest: true` automatically converts tags to digests at admission
- **Signature Verification**: Cosign signatures with keyless attestors for GitHub Actions
- **Registry Allowlist**: `anyPattern` with approved registries (ghcr.io, quay.io, docker.io, etc.)
- **Attestation Validation**: Required attestors with `count: 1` for supply chain integrity

```yaml
# Kyverno image verification
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-images
spec:
  rules:
  - name: verify-image-signatures
    verifyImages:
    - imageReferences:
      - "ghcr.io/aegis-framework/*"
      key: |
        -----BEGIN PUBLIC KEY-----
        MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
        -----END PUBLIC KEY-----
```

#### Vulnerability Scanning
- **Continuous Scanning**: Trivy Operator for real-time vulnerability assessment
- **Severity Thresholds**: HIGH and CRITICAL vulnerabilities block deployment
- **SBOM Generation**: Software Bill of Materials for dependency tracking

### 5. Runtime Security

#### Admission Control
- **Kyverno Policies**: Validate resources at admission time
- **Privilege Escalation**: Prevent privilege escalation attempts
- **Resource Limits**: Enforce CPU and memory limits

```yaml
# Kyverno security policies
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privilege-escalation
spec:
  rules:
  - name: block-privilege-escalation
    validate:
      pattern:
        spec:
          containers:
          - securityContext:
              allowPrivilegeEscalation: false
```

#### Runtime Monitoring
- **Policy Reports**: Kyverno generates policy violation reports
- **Audit Logs**: Comprehensive audit logging for security events
- **Alerting**: Real-time alerts for security violations

### 6. Infrastructure Security

#### Control Plane Security
- **etcd Encryption**: `encryptedVolume: true` for all etcd members
- **Secrets Encryption**: `encryptionConfig: true` with AES-CBC provider
- **API Server Access**: Restricted `kubernetesApiAccess` to private networks only
- **SSH Access**: Limited `sshAccess` to VPC and private network ranges

```yaml
# Encryption Configuration
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <encryption-key>
```

#### Node Security
- **Instance Profiles**: Least-privilege IAM roles for nodes
- **Security Groups**: Minimal network access rules
- **SSH Access**: Key-based authentication with restricted access

## Security Validation

### Automated Testing
```bash
# Full cluster validation
./scripts/validate-cluster.sh

# TLS validation with CA certificates
./scripts/tls-validation.sh

# Kyverno policy tests
kubectl apply -f tests/kyverno-test.yaml

# Certificate rotation
./scripts/cert-rotation.sh --check-all
```

### Manual Verification
- [ ] PSA labels applied to all namespaces
- [ ] NetworkPolicies block unauthorized traffic
- [ ] Certificates validated without -k flag
- [ ] Images signed and attested
- [ ] IRSA roles functioning correctly
- [ ] ArgoCD secured with OIDC
- [ ] etcd and Secrets encryption enabled

## Incident Response

### Security Events
1. **Detection**: Monitor Kyverno policy reports and Trivy scans
2. **Assessment**: Evaluate impact and scope of security violation
3. **Containment**: Isolate affected resources and revoke access
4. **Recovery**: Restore from clean backups and apply fixes
5. **Lessons Learned**: Update policies and procedures

### Emergency Contacts
- **Security Team**: security@aegis-framework.com
- **Platform Team**: platform@aegis-framework.com
- **On-call Engineer**: oncall@aegis-framework.com

## Compliance

### Standards Alignment
- **NIST Cybersecurity Framework**: Identify, Protect, Detect, Respond, Recover
- **CIS Kubernetes Benchmarks**: Industry-standard security configurations
- **OWASP Kubernetes Top 10**: Address common Kubernetes security risks

### Audit Requirements
- **Access Logs**: All authentication and authorization events
- **Change Logs**: Configuration and policy changes
- **Security Events**: Policy violations and security incidents
- **Compliance Reports**: Automated compliance status reporting

## Security Maintenance

### Regular Activities
- **Certificate Renewal**: Monitor and renew certificates before expiry
- **Policy Updates**: Review and update Kyverno policies
- **Vulnerability Patching**: Apply security patches promptly
- **Access Reviews**: Regular review of IAM roles and permissions

### Security Assessments
- **Quarterly Reviews**: Comprehensive security assessment
- **Penetration Testing**: Authorized testing of security controls
- **Code Reviews**: Security review of infrastructure code
- **Dependency Updates**: Regular updates of security dependencies
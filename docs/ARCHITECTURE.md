# Architecture Overview

The Aegis Kubernetes Framework provides a secure, scalable, and automated platform for running containerized workloads on AWS using Kubernetes.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Aegis Kubernetes Framework                    │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │  GitOps     │  │  Security   │  │  Automation │  │  Infra  │ │
│  │  (ArgoCD)   │  │  (Istio)    │  │  (Go CLI)   │  │  (TF)   │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Kubernetes Cluster (kops)                 │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │   │
│  │  │ Control     │  │ Worker      │  │ Security    │       │   │
│  │  │ Plane       │  │ Nodes       │  │ Components  │       │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘       │   │
│  └─────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                 AWS Infrastructure                      │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │   │
│  │  │ VPC         │  │ IAM         │  │ S3         │       │   │
│  │  │ Network     │  │ Roles       │  │ State      │       │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘       │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Core Components

### Infrastructure Layer

#### Terraform Modules
- **VPC Module** (Enhanced): Creates secure network foundation with improved reliability
  - Public/private subnets across multiple AZs with proper dependency management
  - NAT gateways for outbound traffic with explicit resource ordering
  - Security groups with minimal access and consistent tagging strategy
  - Route tables and network ACLs with comprehensive tagging
  - Input validation for CIDR blocks and availability zones

- **IAM Module** (Enhanced): Manages access and permissions with security-first approach
  - **Critical Fix**: kops service role with custom least-privilege policies (replacing AdministratorAccess)
  - Node instance profiles with minimal required permissions
  - Region-scoped and resource-specific access controls
  - Cross-account access configurations with proper boundaries

- **S3 Module** (Enhanced): Provides secure state storage with improved naming
  - Encrypted bucket for Terraform state with comprehensive access controls
  - Versioning and lifecycle policies with proper tagging
  - kops cluster state storage with unique bucket naming
  - Public access blocking and server-side encryption
  - Input validation for tags and environment-specific naming

### Cluster Layer

#### kops Configuration
- **Multi-AZ Control Plane**: HA master nodes
- **Scalable Worker Nodes**: Auto-scaling node groups
- **etcd Encryption**: Secure key-value storage
- **Network Policies**: Calico CNI integration

#### Instance Groups
- **Master Nodes**: Control plane components
- **Worker Nodes**: Application workloads
- **Bastion Hosts**: Secure administrative access

### Security Layer

#### Istio Service Mesh
- **Sidecar Injection**: Automatic proxy deployment
- **Mutual TLS**: Encrypted service communication
- **Traffic Management**: Intelligent routing and load balancing
- **Observability**: Distributed tracing and metrics

#### Kyverno Policies
- **Admission Control**: Policy-based resource validation
- **Image Security**: Signature verification and scanning
- **Pod Security**: Runtime security enforcement
- **Compliance**: Automated security checks

#### Trivy Scanner
- **Vulnerability Detection**: CVE scanning and reporting
- **Secret Detection**: Sensitive data identification
- **Configuration Auditing**: Security misconfigurations
- **SBOM Generation**: Software bill of materials

### Automation Layer

#### Go CLI Tool
- **Infrastructure Provisioning**: Automated Terraform execution
- **Cluster Management**: kops lifecycle operations
- **Configuration Generation**: Template processing
- **Validation**: Health checks and compliance

#### GitOps with ArgoCD
- **Application Management**: Declarative deployments
- **Configuration Drift**: Automatic reconciliation
- **Multi-environment**: Environment-specific configurations
- **RBAC**: Access control and audit trails

## Data Flow

### Provisioning Flow
```
Git Repository → Go CLI → Terraform → AWS Infrastructure
                    ↓
            kops → Kubernetes Cluster
                    ↓
            ArgoCD → Security Components
```

### Application Deployment Flow
```
Developer → Git Commit → ArgoCD → Kubernetes
                    ↓
            Kyverno → Policy Validation
                    ↓
            Istio → Service Mesh
```

### Security Validation Flow
```
Container Image → Cosign → Signature Verification
                    ↓
            Trivy → Vulnerability Scan
                    ↓
            Kyverno → Policy Enforcement
```

## Network Architecture

### VPC Design
```
VPC (10.0.0.0/16)
├── Public Subnets (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)
│   ├── Internet Gateway
│   ├── NAT Gateways
│   └── Load Balancers
├── Private Subnets (10.0.10.0/24, 10.0.11.0/24, 10.0.12.0/24)
│   ├── Worker Nodes
│   ├── Control Plane
│   └── Internal Services
└── Security Groups
    ├── Control Plane SG
    ├── Worker Node SG
    └── Load Balancer SG
```

### Service Mesh Topology
```
Internet → Istio Gateway → Virtual Service → Destination Rule → Service
                    ↓
            Peer Authentication (mTLS)
                    ↓
            Authorization Policy
```

## Security Architecture

### Zero Trust Model
- **Identity Verification**: Every request authenticated
- **Authorization**: Fine-grained access control
- **Encryption**: End-to-end encryption
- **Continuous Validation**: Ongoing security assessment

### Defense in Depth
- **Network Layer**: VPC security groups and NACLs with proper dependency management
- **Host Layer**: Instance hardening and monitoring with consistent tagging
- **Container Layer**: Image scanning and runtime protection with Kyverno policies
- **Application Layer**: Service mesh and API security with mTLS enforcement
- **Certificate Layer**: Automated certificate rotation and validation
- **etcd Layer**: Encryption validation and access restrictions

### Validation & Compliance (New)
- **Automated Health Checks**: `validate-cluster.sh` for comprehensive cluster validation
- **Security Compliance**: `validate-compliance.sh` with JSON reporting and scoring
- **Policy Enforcement**: Real-time Kyverno policy violation monitoring
- **Infrastructure Validation**: Terraform input validation with regex and type checking
- **Multi-layer Assessment**: Network, container, and infrastructure security validation

## Scalability Considerations

### Horizontal Scaling
- **Cluster Autoscaling**: Node groups scale based on demand
- **Pod Autoscaling**: HPA based on metrics
- **Multi-cluster**: Regional distribution for global scale

### Performance Optimization
- **Network Policies**: Efficient traffic filtering
- **Resource Limits**: Pod resource management
- **Caching**: Image and package caching
- **CDN Integration**: Static asset delivery

## High Availability

### Control Plane HA
- **Multi-AZ Deployment**: Masters across availability zones
- **etcd Clustering**: Distributed key-value store
- **Load Balancing**: API server load distribution

### Application HA
- **Pod Disruption Budgets**: Maintain minimum replicas
- **Anti-affinity**: Spread workloads across nodes
- **Health Checks**: Automated failure detection

## Monitoring and Observability

### Metrics Collection
- **Infrastructure Metrics**: CloudWatch integration
- **Application Metrics**: Prometheus and Grafana
- **Security Metrics**: Audit logs and alerts

### Logging Architecture
- **Centralized Logging**: Fluentd log aggregation
- **Log Storage**: S3 and Elasticsearch
- **Log Analysis**: Kibana dashboards

## Disaster Recovery

### Backup Strategy
- **etcd Backups**: Automated snapshots
- **Persistent Volumes**: Cross-region replication
- **Configuration Backups**: Git-based configuration

### Recovery Procedures
- **Cluster Recovery**: kops cluster restoration
- **Data Recovery**: Volume snapshot restoration
- **Application Recovery**: ArgoCD application sync

## Multi-Environment Support

### Environment Isolation
- **Separate VPCs**: Network isolation
- **Dedicated Clusters**: Environment-specific clusters
- **Access Controls**: Environment-specific IAM roles

### Configuration Management
- **Git Branches**: Environment-specific configurations
- **Parameter Stores**: Environment variables
- **Secrets Management**: Environment-specific secrets

## Integration Points

### AWS Services
- **EC2**: Compute instances
- **VPC**: Network infrastructure
- **IAM**: Identity and access management
- **S3**: Object storage
- **CloudWatch**: Monitoring and logging
- **KMS**: Key management

### Third-Party Tools
- **kops**: Kubernetes cluster management
- **ArgoCD**: GitOps continuous delivery
- **Istio**: Service mesh
- **Kyverno**: Policy engine
- **Trivy**: Vulnerability scanner
- **Cosign**: Container signing

## Future Enhancements

### Planned Features
- **Service Mesh Expansion**: Multi-cluster service mesh
- **Advanced Security**: Runtime protection and AI-based threat detection
- **Observability**: Distributed tracing and advanced monitoring
- **Automation**: AI-assisted operations and self-healing

### Technology Evolution
- **Kubernetes Updates**: Automated cluster upgrades
- **Security Updates**: Continuous security improvements
- **Performance Optimization**: Advanced caching and optimization
- **Cost Optimization**: Automated resource optimization
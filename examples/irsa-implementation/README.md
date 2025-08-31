# IAM Roles for Service Accounts (IRSA) Implementation

This directory contains comprehensive examples of implementing **IAM Roles for Service Accounts (IRSA)** in the Aegis Kubernetes Framework. IRSA allows Kubernetes pods to assume AWS IAM roles securely without storing access keys.

## 📋 **What is IRSA?**

IRSA enables Kubernetes service accounts to assume AWS IAM roles through OpenID Connect (OIDC) federation, providing:

- ✅ **Secure credential management** - No access keys in pods
- ✅ **Fine-grained permissions** - Pod-level IAM permissions
- ✅ **Short-lived credentials** - Automatic credential rotation
- ✅ **Audit trail** - IAM role assumption logging

## 🏗️ **Architecture**

```
Kubernetes Pod
    ↓ (Service Account Token)
OIDC Provider (EKS/kops)
    ↓ (JWT Token Validation)
AWS STS AssumeRoleWithWebIdentity
    ↓ (Temporary Credentials)
AWS Service (S3, DynamoDB, etc.)
```

## 📁 **Directory Structure**

```
examples/irsa-implementation/
├── README.md                           # This file
├── terraform/                         # Infrastructure as Code
│   ├── oidc-provider.tf               # OIDC provider setup
│   ├── iam-roles.tf                   # IAM roles for pods
│   └── variables.tf                   # Configuration variables
├── manifests/                         # Kubernetes manifests
│   ├── service-accounts/              # Service account definitions
│   ├── deployments/                   # Sample applications
│   └── rbac/                          # RBAC configurations
├── scripts/                           # Automation scripts
│   ├── setup-irsa.sh                  # Automated setup
│   └── test-irsa.sh                   # Testing and validation
└── docs/                             # Documentation
    ├── setup-guide.md                 # Step-by-step setup
    ├── troubleshooting.md             # Common issues
    └── security-considerations.md     # Security implications
```

## 🚀 **Quick Start**

### **Prerequisites**
- Kubernetes cluster with OIDC enabled
- AWS CLI configured
- kubectl configured
- Terraform >= 1.0

### **Basic Setup**
```bash
# 1. Setup OIDC provider and IAM roles
cd examples/irsa-implementation/terraform
terraform init
terraform apply

# 2. Deploy sample application
kubectl apply -f ../manifests/service-accounts/
kubectl apply -f ../manifests/deployments/

# 3. Test IRSA functionality
kubectl apply -f ../manifests/test-pods/
```

## 🎯 **Example Scenarios**

### **Scenario 1: S3 Access**
Application needs to read/write to S3 bucket
- **Service Account**: `s3-access-sa`
- **IAM Role**: `S3ReadWriteAccess`
- **Use Case**: Backup applications, file processing

### **Scenario 2: DynamoDB Access**
Application needs to access DynamoDB table
- **Service Account**: `dynamodb-access-sa`
- **IAM Role**: `DynamoDBFullAccess`
- **Use Case**: Data processing, caching

### **Scenario 3: CloudWatch Logs**
Application needs to write logs to CloudWatch
- **Service Account**: `cloudwatch-access-sa`
- **IAM Role**: `CloudWatchLogsFullAccess`
- **Use Case**: Centralized logging

## 🔧 **Implementation Details**

### **OIDC Provider Setup**
```hcl
# terraform/oidc-provider.tf
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}
```

### **IAM Role Creation**
```hcl
# terraform/iam-roles.tf
resource "aws_iam_role" "s3_access" {
  name = "${var.cluster_name}-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Condition = {
          StringEquals = {
            "${aws_iam_openid_connect_provider.cluster.url}:sub": "system:serviceaccount:default:s3-access-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.s3_access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}
```

### **Service Account Configuration**
```yaml
# manifests/service-accounts/s3-access-sa.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-access-sa
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/cluster-s3-access-role
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: s3-access-role
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: s3-access-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: s3-access-role
subjects:
- kind: ServiceAccount
  name: s3-access-sa
  namespace: default
```

### **Sample Application**
```yaml
# manifests/deployments/s3-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: s3-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: s3-app
  template:
    metadata:
      labels:
        app: s3-app
    spec:
      serviceAccountName: s3-access-sa
      containers:
      - name: s3-app
        image: amazonlinux:2
        command:
        - /bin/bash
        - -c
        - |
          # Test S3 access using IRSA
          aws s3 ls s3://my-bucket/
          echo "IRSA working - S3 access successful"
          sleep 3600
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
```

## 🧪 **Testing IRSA**

### **Automated Testing**
```bash
# Run IRSA tests
kubectl apply -f manifests/test-pods/

# Check pod logs
kubectl logs -f test-s3-access

# Verify IAM role assumption
kubectl describe pod test-s3-access
```

### **Manual Testing**
```bash
# Test from within cluster
kubectl run test-irsa --image=amazonlinux:2 --rm -it \
  --serviceaccount=s3-access-sa \
  -- aws sts get-caller-identity

# Expected output:
# {
#     "UserId": "AROA...",
#     "Account": "123456789012",
#     "Arn": "arn:aws:sts::123456789012:assumed-role/cluster-s3-access-role/..."
# }
```

## 🔒 **Security Considerations**

### **Principle of Least Privilege**
- Grant only required permissions
- Use resource-level restrictions
- Regular permission audits

### **Token Management**
- Tokens are short-lived (15 minutes)
- Automatic rotation handled by AWS
- No credential storage in pods

### **Network Security**
- Use VPC endpoints for AWS services
- Implement network policies
- Enable service mesh encryption

## 📊 **Monitoring and Observability**

### **IRSA Metrics**
```yaml
# Prometheus metrics for IRSA
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: irsa-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: irsa-app
  endpoints:
  - port: metrics
    interval: 30s
```

### **Audit Logging**
```bash
# CloudTrail events for IRSA
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity
```

## 🚀 **Advanced Usage**

### **Multi-Account IRSA**
```hcl
# Cross-account role assumption
resource "aws_iam_role" "cross_account_s3" {
  name = "cross-account-s3-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::TARGET-ACCOUNT:role/OrganizationAccountAccessRole"
        }
      }
    ]
  })
}
```

### **Conditional Role Assumption**
```hcl
# Role assumption based on namespace
resource "aws_iam_role" "conditional_access" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Condition = {
          StringLike = {
            "${aws_iam_openid_connect_provider.cluster.url}:sub": "system:serviceaccount:production:*"
          }
        }
      }
    ]
  })
}
```

## 📋 **Troubleshooting**

### **Common Issues**

1. **OIDC Provider Not Found**
```bash
# Check OIDC provider
aws iam list-open-id-connect-providers

# Verify thumbprint
openssl s_client -servername your-oidc-provider -showcerts < /dev/null 2>/dev/null | openssl x509 -fingerprint -noout
```

2. **Role Assumption Fails**
```bash
# Check service account annotation
kubectl describe serviceaccount s3-access-sa

# Verify IAM role trust policy
aws iam get-role --role-name cluster-s3-access-role --query 'Role.AssumeRolePolicyDocument'
```

3. **Permission Denied**
```bash
# Check attached policies
aws iam list-attached-role-policies --role-name cluster-s3-access-role

# Test with elevated permissions
aws sts assume-role --role-arn arn:aws:iam::123456789012:role/cluster-s3-access-role --role-session-name test
```

## 🎯 **Best Practices**

### **IAM Role Design**
1. **Use descriptive names**: `cluster-service-permission-role`
2. **Implement least privilege**: Grant minimum required permissions
3. **Use resource restrictions**: Limit to specific S3 buckets, DynamoDB tables
4. **Regular audits**: Review and update permissions periodically

### **Service Account Management**
1. **Namespace isolation**: Use different service accounts per namespace
2. **RBAC integration**: Combine with Kubernetes RBAC
3. **Pod security**: Run with appropriate security contexts
4. **Monitoring**: Track service account usage

### **Operational Excellence**
1. **Documentation**: Maintain clear role and permission documentation
2. **Change management**: Use GitOps for IAM policy changes
3. **Incident response**: Have procedures for credential compromise
4. **Compliance**: Regular security assessments and audits

## 📚 **Additional Resources**

- [AWS IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Kubernetes Service Accounts](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
- [OIDC Federation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)

## 🎉 **Conclusion**

This IRSA implementation provides a secure, scalable, and manageable way to grant AWS permissions to Kubernetes workloads. The examples demonstrate various scenarios and best practices for implementing IRSA in production environments.

The implementation includes:
- ✅ Complete Terraform automation
- ✅ Production-ready Kubernetes manifests
- ✅ Comprehensive testing and validation
- ✅ Security best practices and monitoring
- ✅ Troubleshooting guides and documentation

Start with the basic S3 access example and expand to more complex scenarios as your requirements grow. 🚀🔒
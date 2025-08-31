# IRSA Setup Guide

This guide provides step-by-step instructions for implementing IAM Roles for Service Accounts (IRSA) in the Aegis Kubernetes Framework.

## Prerequisites

### 1. EKS Cluster with OIDC
```bash
# For EKS clusters, OIDC is enabled by default
aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer"
```

### 2. Required Tools
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com jammy main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Verify installations
aws --version
terraform --version
kubectl version --client
```

### 3. AWS Permissions
Your AWS user/role needs these permissions:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateOpenIDConnectProvider",
                "iam:GetOpenIDConnectProvider",
                "iam:CreateRole",
                "iam:GetRole",
                "iam:AttachRolePolicy",
                "iam:CreatePolicy"
            ],
            "Resource": "*"
        }
    ]
}
```

## Step-by-Step Setup

### Step 1: Configure Environment

```bash
# Set environment variables
export CLUSTER_NAME="aegis-cluster"
export AWS_REGION="us-east-1"
export ENVIRONMENT="dev"
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

# Verify configuration
echo "Cluster: $CLUSTER_NAME"
echo "Region: $AWS_REGION"
echo "Account: $AWS_ACCOUNT_ID"
```

### Step 2: Setup Terraform Infrastructure

```bash
# Navigate to Terraform directory
cd examples/irsa-implementation/terraform

# Initialize Terraform
terraform init

# Create terraform.tfvars file
cat > terraform.tfvars << EOF
cluster_name = "$CLUSTER_NAME"
environment = "$ENVIRONMENT"
aws_region = "$AWS_REGION"
aws_account_id = "$AWS_ACCOUNT_ID"
EOF

# Plan the infrastructure
terraform plan

# Apply the infrastructure
terraform apply

# Note the output values
terraform output
```

### Step 3: Update Kubernetes Manifests

```bash
# Get IAM role ARNs from Terraform output
S3_ROLE_ARN=$(terraform output -raw s3_access_role_arn)
DYNAMODB_ROLE_ARN=$(terraform output -raw dynamodb_access_role_arn)

# Update service account manifests
sed -i "s|arn:aws:iam::123456789012:role/cluster-s3-access-role|$S3_ROLE_ARN|" \
    ../manifests/service-accounts/s3-access-sa.yaml

# Verify the updates
grep eks.amazonaws.com/role-arn ../manifests/service-accounts/s3-access-sa.yaml
```

### Step 4: Deploy Kubernetes Resources

```bash
# Deploy service accounts
kubectl apply -f ../manifests/service-accounts/

# Deploy RBAC policies
kubectl apply -f ../manifests/rbac/

# Deploy sample application
kubectl apply -f ../manifests/deployments/

# Verify deployments
kubectl get serviceaccounts -l aegis.example=irsa
kubectl get pods -l aegis.example=irsa
```

### Step 5: Test IRSA Functionality

```bash
# Deploy test pod
kubectl apply -f ../manifests/test-pods/test-s3-access.yaml

# Wait for test to complete
kubectl wait --for=condition=completed pod/test-s3-access --timeout=300s

# Check test results
kubectl logs pod/test-s3-access

# Expected output:
# === IRSA Validation Test ===
# 1. Checking AWS credentials...
# ✅ AWS credentials available
# 2. Checking assumed IAM role...
#    Role ARN: arn:aws:sts::123456789012:assumed-role/cluster-s3-access-role/...
# ✅ Correct IAM role assumed
```

## Automated Setup

Use the provided setup script for automated deployment:

```bash
# Make script executable
chmod +x examples/irsa-implementation/scripts/setup-irsa.sh

# Full automated setup
./examples/irsa-implementation/scripts/setup-irsa.sh --full-setup

# Or step-by-step setup
./examples/irsa-implementation/scripts/setup-irsa.sh --setup-terraform
./examples/irsa-implementation/scripts/setup-irsa.sh --update-manifests
./examples/irsa-implementation/scripts/setup-irsa.sh --deploy-k8s
./examples/irsa-implementation/scripts/setup-irsa.sh --test
```

## Configuration Examples

### 1. Basic S3 Access

**IAM Role (Terraform):**
```hcl
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

**Service Account (Kubernetes):**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-access-sa
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/cluster-s3-access-role
```

**Application Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: s3-app
spec:
  template:
    spec:
      serviceAccountName: s3-access-sa
      containers:
      - name: app
        image: amazonlinux:2
        command:
        - aws
        - s3
        - ls
```

### 2. DynamoDB Access

**IAM Role:**
```hcl
resource "aws_iam_role" "dynamodb_access" {
  name = "${var.cluster_name}-dynamodb-access-role"

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
            "${aws_iam_openid_connect_provider.cluster.url}:sub": "system:serviceaccount:default:dynamodb-access-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dynamodb_access" {
  role       = aws_iam_role.dynamodb_access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBReadOnlyAccess"
}
```

### 3. Custom Permissions

**Custom IAM Policy:**
```hcl
resource "aws_iam_policy" "custom_s3" {
  name = "${var.cluster_name}-custom-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${var.cluster_name}-data/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "custom_s3" {
  role       = aws_iam_role.s3_access.name
  policy_arn = aws_iam_policy.custom_s3.arn
}
```

### 4. Multi-Namespace Access

**IAM Role for Multiple Namespaces:**
```hcl
resource "aws_iam_role" "multi_namespace" {
  name = "${var.cluster_name}-multi-namespace-role"

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
            "${aws_iam_openid_connect_provider.cluster.url}:sub": "system:serviceaccount:*:multi-namespace-sa"
          }
        }
      }
    ]
  })
}
```

## Troubleshooting

### Common Issues

#### 1. OIDC Provider Not Found
```bash
# Check if OIDC provider exists
aws iam list-open-id-connect-providers

# Create OIDC provider manually if needed
aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer"
# Use the issuer URL to create OIDC provider
```

#### 2. Role Assumption Fails
```bash
# Check service account annotation
kubectl describe serviceaccount s3-access-sa

# Verify IAM role trust policy
aws iam get-role --role-name cluster-s3-access-role --query 'Role.AssumeRolePolicyDocument'

# Check OIDC thumbprint
aws iam get-open-id-connect-provider --openid-connect-provider-arn $OIDC_ARN
```

#### 3. Permission Denied
```bash
# Check attached policies
aws iam list-attached-role-policies --role-name cluster-s3-access-role

# Test role assumption manually
aws sts assume-role-with-web-identity \
  --role-arn arn:aws:iam::123456789012:role/cluster-s3-access-role \
  --role-session-name test \
  --web-identity-token $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
```

#### 4. Token Expired
```bash
# Check service account token
kubectl get secrets -n default | grep s3-access-sa

# Describe the token
kubectl describe secret s3-access-sa-token-xxxxx -n default

# The token should be automatically refreshed by Kubernetes
```

### Debug Commands

```bash
# Check pod identity
kubectl exec -it deployment/s3-app -- aws sts get-caller-identity

# Check service account
kubectl get serviceaccount s3-access-sa -o yaml

# Check OIDC provider
aws iam get-open-id-connect-provider --openid-connect-provider-arn $OIDC_ARN

# Check IAM role
aws iam get-role --role-name cluster-s3-access-role

# Check CloudTrail for role assumptions
aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity
```

## Security Considerations

### 1. Principle of Least Privilege
- Grant only required permissions
- Use resource-level restrictions
- Regular permission audits

### 2. Token Management
- Tokens are automatically rotated
- No credential storage in pods
- Secure token distribution

### 3. Network Security
- Use VPC endpoints for AWS services
- Implement network policies
- Enable service mesh encryption

## Monitoring and Alerting

### CloudWatch Metrics
```bash
# Monitor role assumptions
aws cloudwatch get-metric-statistics \
  --namespace AWS/IAM \
  --metric-name AssumeRoleWithWebIdentity \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

### Prometheus Metrics
```yaml
# ServiceMonitor for IRSA metrics
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: irsa-monitor
spec:
  selector:
    matchLabels:
      app: irsa-app
  endpoints:
  - port: metrics
    path: /metrics
```

## Advanced Usage

### 1. Cross-Account IRSA
```hcl
# Cross-account role assumption
resource "aws_iam_role" "cross_account" {
  name = "cross-account-irsa-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::TARGET-ACCOUNT:root"
        }
      }
    ]
  })
}
```

### 2. Conditional Role Access
```hcl
# Role based on namespace
resource "aws_iam_role" "namespace_specific" {
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

### 3. Session Tags
```hcl
# Add session tags for better auditing
resource "aws_iam_role" "tagged_role" {
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
            "${aws_iam_openid_connect_provider.cluster.url}:sub": "system:serviceaccount:default:tagged-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "session_tags" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:TagSession"
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}
```

## Best Practices

### IAM Role Design
1. **Descriptive names**: `cluster-service-permission-role`
2. **Environment separation**: Include environment in role names
3. **Service isolation**: One role per service/purpose
4. **Regular audits**: Review and update permissions

### Service Account Management
1. **Namespace isolation**: Different SAs per namespace
2. **RBAC integration**: Combine with Kubernetes RBAC
3. **Pod security**: Run with appropriate security contexts
4. **Monitoring**: Track SA usage and role assumptions

### Operational Excellence
1. **Documentation**: Maintain clear role and permission docs
2. **Change management**: Use GitOps for IAM changes
3. **Incident response**: Procedures for credential issues
4. **Compliance**: Regular security assessments

## Migration from KIAM

If migrating from KIAM to IRSA:

1. **Update service accounts** with IRSA annotations
2. **Remove KIAM agents** from nodes
3. **Update IAM trust policies** for OIDC
4. **Test applications** with new credentials
5. **Monitor role assumptions** in CloudTrail

## Next Steps

1. **Customize for Your Environment**
   - Update DNS names and IP addresses
   - Modify security policies for your requirements
   - Configure monitoring to match your stack

2. **Scale to Production**
   - Implement high availability
   - Set up automated testing
   - Configure disaster recovery

3. **Advanced Features**
   - Implement cross-account access
   - Add session tagging
   - Configure conditional access

This IRSA implementation provides a secure, scalable foundation for granting AWS permissions to Kubernetes workloads. The examples can be customized and extended based on your specific requirements.
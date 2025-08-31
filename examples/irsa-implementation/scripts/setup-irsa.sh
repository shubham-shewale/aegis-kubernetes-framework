#!/bin/bash

# IRSA Setup Script
# Automates the setup of IAM Roles for Service Accounts

set -e

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-aegis-cluster}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a irsa-setup.log
}

# Error handling
error() {
    log "${RED}ERROR: $*${NC}"
    exit 1
}

# Success message
success() {
    log "${GREEN}SUCCESS: $*${NC}"
}

# Warning message
warning() {
    log "${YELLOW}WARNING: $*${NC}"
}

# Info message
info() {
    log "${BLUE}INFO: $*${NC}"
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."

    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed"
    fi

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed"
    fi

    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        error "Terraform is not installed"
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials are not configured"
    fi

    # Check cluster access
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot access Kubernetes cluster"
    fi

    success "Prerequisites check passed"
}

# Setup Terraform infrastructure
setup_terraform() {
    info "Setting up Terraform infrastructure..."

    cd terraform

    # Initialize Terraform
    terraform init

    # Create terraform.tfvars
    cat > terraform.tfvars << EOF
cluster_name = "$CLUSTER_NAME"
environment = "$ENVIRONMENT"
aws_region = "$AWS_REGION"
aws_account_id = "$(aws sts get-caller-identity --query Account --output text)"
EOF

    # Plan and apply
    terraform plan -out=tfplan
    terraform apply tfplan

    # Get outputs
    S3_ROLE_ARN=$(terraform output -raw s3_access_role_arn)
    DYNAMODB_ROLE_ARN=$(terraform output -raw dynamodb_access_role_arn)
    CLOUDWATCH_ROLE_ARN=$(terraform output -raw cloudwatch_access_role_arn)

    cd ..
    success "Terraform infrastructure setup completed"
}

# Update Kubernetes manifests with IAM role ARNs
update_manifests() {
    info "Updating Kubernetes manifests with IAM role ARNs..."

    # Update S3 service account
    sed -i.bak "s|arn:aws:iam::123456789012:role/cluster-s3-access-role|$S3_ROLE_ARN|g" \
        manifests/service-accounts/s3-access-sa.yaml

    # Update DynamoDB service account (if exists)
    if [ -f "manifests/service-accounts/dynamodb-access-sa.yaml" ]; then
        sed -i.bak "s|arn:aws:iam::123456789012:role/cluster-dynamodb-access-role|$DYNAMODB_ROLE_ARN|g" \
            manifests/service-accounts/dynamodb-access-sa.yaml
    fi

    # Update CloudWatch service account (if exists)
    if [ -f "manifests/service-accounts/cloudwatch-access-sa.yaml" ]; then
        sed -i.bak "s|arn:aws:iam::123456789012:role/cluster-cloudwatch-access-role|$CLOUDWATCH_ROLE_ARN|g" \
            manifests/service-accounts/cloudwatch-access-sa.yaml
    fi

    success "Kubernetes manifests updated"
}

# Deploy Kubernetes resources
deploy_kubernetes() {
    info "Deploying Kubernetes resources..."

    # Deploy service accounts
    kubectl apply -f manifests/service-accounts/

    # Deploy RBAC
    kubectl apply -f manifests/rbac/

    # Deploy test pods
    kubectl apply -f manifests/test-pods/

    # Deploy sample application
    kubectl apply -f manifests/deployments/

    success "Kubernetes resources deployed"
}

# Test IRSA functionality
test_irsa() {
    info "Testing IRSA functionality..."

    # Wait for test pod to complete
    kubectl wait --for=condition=completed pod/test-s3-access --timeout=300s

    # Check test results
    if kubectl logs pod/test-s3-access | grep -q "IRSA is working correctly"; then
        success "IRSA test passed!"
    else
        error "IRSA test failed"
        kubectl logs pod/test-s3-access
        exit 1
    fi
}

# Validate setup
validate_setup() {
    info "Validating IRSA setup..."

    # Check OIDC provider
    OIDC_ARN=$(aws iam list-open-id-connect-providers | jq -r '.OpenIDConnectProviderList[0].Arn' 2>/dev/null)
    if [ -n "$OIDC_ARN" ]; then
        success "OIDC provider found: $OIDC_ARN"
    else
        warning "OIDC provider not found"
    fi

    # Check IAM roles
    ROLES=$(aws iam list-roles --query 'Roles[?contains(RoleName, `irsa`)].RoleName' --output text)
    if [ -n "$ROLES" ]; then
        success "IRSA IAM roles found: $ROLES"
    else
        warning "No IRSA IAM roles found"
    fi

    # Check service accounts
    SA_COUNT=$(kubectl get serviceaccounts -A -l aegis.example=irsa | wc -l)
    if [ "$SA_COUNT" -gt 0 ]; then
        success "IRSA service accounts found: $((SA_COUNT-1))"
    else
        warning "No IRSA service accounts found"
    fi

    # Check running pods
    POD_COUNT=$(kubectl get pods -A -l aegis.example=irsa | wc -l)
    if [ "$POD_COUNT" -gt 0 ]; then
        success "IRSA pods running: $((POD_COUNT-1))"
    else
        warning "No IRSA pods running"
    fi
}

# Cleanup function
cleanup() {
    info "Cleaning up temporary files..."
    find . -name "*.bak" -delete
    rm -f terraform/terraform.tfvars
}

# Main function
main() {
    case "${1:-}" in
        --setup-terraform)
            check_prerequisites
            setup_terraform
            ;;
        --update-manifests)
            update_manifests
            ;;
        --deploy-k8s)
            check_prerequisites
            deploy_kubernetes
            ;;
        --test)
            check_prerequisites
            test_irsa
            ;;
        --validate)
            check_prerequisites
            validate_setup
            ;;
        --full-setup)
            info "Starting full IRSA setup..."
            check_prerequisites
            setup_terraform
            update_manifests
            deploy_kubernetes
            test_irsa
            validate_setup
            cleanup
            success "Full IRSA setup completed!"
            ;;
        --cleanup)
            cleanup
            ;;
        --help|*)
            echo "IRSA Setup Script"
            echo ""
            echo "Usage: $0 [OPTION]"
            echo ""
            echo "Options:"
            echo "  --setup-terraform    Setup Terraform infrastructure"
            echo "  --update-manifests   Update manifests with IAM role ARNs"
            echo "  --deploy-k8s         Deploy Kubernetes resources"
            echo "  --test               Test IRSA functionality"
            echo "  --validate           Validate IRSA setup"
            echo "  --full-setup         Complete IRSA setup"
            echo "  --cleanup            Clean up temporary files"
            echo "  --help               Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  CLUSTER_NAME         Kubernetes cluster name (default: aegis-cluster)"
            echo "  AWS_REGION           AWS region (default: us-east-1)"
            echo "  ENVIRONMENT          Environment name (default: dev)"
            ;;
    esac
}

# Run main function
main "$@"
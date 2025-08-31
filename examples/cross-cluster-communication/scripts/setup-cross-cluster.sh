#!/bin/bash

# Cross-Cluster Communication Setup Script
# This script automates the setup of secure cross-cluster communication

set -e

# Configuration
CLUSTER_A_CONTEXT="${CLUSTER_A_CONTEXT:-cluster-a}"
CLUSTER_B_CONTEXT="${CLUSTER_B_CONTEXT:-cluster-b}"
CLUSTER_A_GATEWAY="${CLUSTER_A_GATEWAY:-cluster-a-gateway.aegis.local}"
CLUSTER_B_GATEWAY="${CLUSTER_B_GATEWAY:-cluster-b-gateway.aegis.local}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a setup-cross-cluster.log
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

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed"
    fi

    # Check contexts
    if ! kubectl config get-contexts "$CLUSTER_A_CONTEXT" &> /dev/null; then
        error "Cluster A context '$CLUSTER_A_CONTEXT' not found"
    fi

    if ! kubectl config get-contexts "$CLUSTER_B_CONTEXT" &> /dev/null; then
        error "Cluster B context '$CLUSTER_B_CONTEXT' not found"
    fi

    # Check istioctl
    if ! command -v istioctl &> /dev/null; then
        warning "istioctl not found - Istio federation features may not work"
    fi

    success "Prerequisites check passed"
}

# Setup cluster A
setup_cluster_a() {
    info "Setting up Cluster A cross-cluster communication..."

    # Switch to cluster A context
    kubectl config use-context "$CLUSTER_A_CONTEXT"

    # Deploy frontend application
    info "Deploying frontend application to Cluster A..."
    kubectl apply -f ../cluster-a/apps/frontend-app.yaml

    # Wait for deployment
    kubectl wait --for=condition=available --timeout=300s deployment/frontend-app -n default

    # Configure Istio federation for cluster A
    info "Configuring Istio federation for Cluster A..."
    kubectl apply -f ../shared/istio/simple-federation.yaml

    # Setup certificates for cluster A
    info "Setting up certificates for Cluster A..."
    kubectl apply -f ../shared/certificates/cross-cluster-certs.yaml

    success "Cluster A setup completed"
}

# Setup cluster B
setup_cluster_b() {
    info "Setting up Cluster B cross-cluster communication..."

    # Switch to cluster B context
    kubectl config use-context "$CLUSTER_B_CONTEXT"

    # Deploy backend API
    info "Deploying backend API to Cluster B..."
    kubectl apply -f ../cluster-b/apps/backend-api.yaml

    # Wait for deployment
    kubectl wait --for=condition=available --timeout=300s deployment/backend-api -n default

    success "Cluster B setup completed"
}

# Configure DNS resolution
configure_dns() {
    info "Configuring DNS resolution for cross-cluster communication..."

    # This would typically involve updating DNS records or load balancer configurations
    # For demonstration, we'll show the required DNS entries

    cat << EOF
Required DNS Configuration:

1. Cluster A Gateway:
   $CLUSTER_A_GATEWAY -> <Cluster A Load Balancer IP/DNS>

2. Cluster B Gateway:
   $CLUSTER_B_GATEWAY -> <Cluster B Load Balancer IP/DNS>

3. Service DNS:
   backend-api.cluster-b.local -> $CLUSTER_B_GATEWAY
   frontend-app.cluster-a.local -> $CLUSTER_A_GATEWAY

Update your DNS provider or /etc/hosts with these entries.
EOF

    warning "DNS configuration required - update your DNS provider with the entries above"
}

# Test cross-cluster communication
test_communication() {
    info "Testing cross-cluster communication..."

    # Switch to cluster A context
    kubectl config use-context "$CLUSTER_A_CONTEXT"

    # Run test connection
    info "Running connectivity test from Cluster A to Cluster B..."
    kubectl apply -f ../cluster-a/manifests/test-connection.yaml

    # Wait for test to complete
    sleep 30

    # Check test results
    if kubectl logs pod/cross-cluster-test -n default | grep -q "All tests completed"; then
        success "Cross-cluster communication test passed!"
    else
        error "Cross-cluster communication test failed"
        kubectl logs pod/cross-cluster-test -n default
        exit 1
    fi
}

# Validate setup
validate_setup() {
    info "Validating cross-cluster setup..."

    # Check cluster A
    kubectl config use-context "$CLUSTER_A_CONTEXT"
    info "Validating Cluster A..."

    # Check deployments
    kubectl get deployments -n default
    kubectl get services -n default

    # Check Istio configuration
    kubectl get serviceentry -n istio-system
    kubectl get virtualservices -n default
    kubectl get destinationrules -n default

    # Check certificates
    kubectl get certificates -A

    # Check cluster B
    kubectl config use-context "$CLUSTER_B_CONTEXT"
    info "Validating Cluster B..."

    # Check deployments
    kubectl get deployments -n default
    kubectl get services -n default

    success "Cross-cluster setup validation completed"
}

# Main function
main() {
    case "${1:-}" in
        --setup-cluster-a)
            check_prerequisites
            setup_cluster_a
            ;;
        --setup-cluster-b)
            check_prerequisites
            setup_cluster_b
            ;;
        --configure-dns)
            configure_dns
            ;;
        --test)
            check_prerequisites
            test_communication
            ;;
        --validate)
            check_prerequisites
            validate_setup
            ;;
        --full-setup)
            info "Starting full cross-cluster setup..."
            check_prerequisites
            setup_cluster_a
            setup_cluster_b
            configure_dns
            test_communication
            validate_setup
            success "Full cross-cluster setup completed!"
            ;;
        --help|*)
            echo "Cross-Cluster Communication Setup Script"
            echo ""
            echo "Usage: $0 [OPTION]"
            echo ""
            echo "Options:"
            echo "  --setup-cluster-a     Setup Cluster A for cross-cluster communication"
            echo "  --setup-cluster-b     Setup Cluster B for cross-cluster communication"
            echo "  --configure-dns       Show DNS configuration requirements"
            echo "  --test                Test cross-cluster communication"
            echo "  --validate            Validate cross-cluster setup"
            echo "  --full-setup          Complete setup of both clusters"
            echo "  --help                Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  CLUSTER_A_CONTEXT     kubectl context for cluster A (default: cluster-a)"
            echo "  CLUSTER_B_CONTEXT     kubectl context for cluster B (default: cluster-b)"
            echo "  CLUSTER_A_GATEWAY     DNS name for cluster A gateway"
            echo "  CLUSTER_B_GATEWAY     DNS name for cluster B gateway"
            ;;
    esac
}

# Run main function
main "$@"
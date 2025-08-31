#!/bin/bash

# Aegis Cluster Validation Script
# Validates cluster health, security compliance, and configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME=${CLUSTER_NAME:-"staging.cluster.aegis.local"}
KUBECONFIG=${KUBECONFIG:-"$HOME/.kube/config"}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi

    if ! command -v kops &> /dev/null; then
        log_error "kops is not installed"
        exit 1
    fi

    if [ ! -f "$KUBECONFIG" ]; then
        log_error "Kubeconfig not found at $KUBECONFIG"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

validate_cluster_connectivity() {
    log_info "Validating cluster connectivity..."

    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to cluster"
        exit 1
    fi

    log_success "Cluster connectivity validated"
}

validate_cluster_health() {
    log_info "Validating cluster health..."

    # Check node status
    local unhealthy_nodes=$(kubectl get nodes --no-headers | grep -v Ready | wc -l)
    if [ "$unhealthy_nodes" -gt 0 ]; then
        log_error "Found $unhealthy_nodes unhealthy nodes"
        kubectl get nodes
        exit 1
    fi

    # Check pod status
    local unhealthy_pods=$(kubectl get pods --all-namespaces --no-headers | grep -v Running | grep -v Completed | wc -l)
    if [ "$unhealthy_pods" -gt 0 ]; then
        log_warn "Found $unhealthy_pods unhealthy pods"
        kubectl get pods --all-namespaces | grep -v Running | grep -v Completed
    fi

    # Check control plane components
    local control_plane_pods=$(kubectl get pods -n kube-system --no-headers | grep -E "(kube-apiserver|kube-controller-manager|kube-scheduler|etcd)" | grep -v Running | wc -l)
    if [ "$control_plane_pods" -gt 0 ]; then
        log_error "Control plane components are not healthy"
        kubectl get pods -n kube-system | grep -E "(kube-apiserver|kube-controller-manager|kube-scheduler|etcd)"
        exit 1
    fi

    log_success "Cluster health validation passed"
}

validate_security_components() {
    log_info "Validating security components..."

    # Check Istio
    if ! kubectl get namespace istio-system &> /dev/null; then
        log_error "Istio namespace not found"
        exit 1
    fi

    local istio_pods=$(kubectl get pods -n istio-system --no-headers | grep -v Running | wc -l)
    if [ "$istio_pods" -gt 0 ]; then
        log_error "Istio pods are not healthy"
        kubectl get pods -n istio-system
        exit 1
    fi

    # Check Kyverno
    if ! kubectl get namespace kyverno &> /dev/null; then
        log_error "Kyverno namespace not found"
        exit 1
    fi

    local kyverno_pods=$(kubectl get pods -n kyverno --no-headers | grep -v Running | wc -l)
    if [ "$kyverno_pods" -gt 0 ]; then
        log_error "Kyverno pods are not healthy"
        kubectl get pods -n kyverno
        exit 1
    fi

    # Check ArgoCD
    if ! kubectl get namespace argocd &> /dev/null; then
        log_error "ArgoCD namespace not found"
        exit 1
    fi

    local argocd_pods=$(kubectl get pods -n argocd --no-headers | grep -v Running | wc -l)
    if [ "$argocd_pods" -gt 0 ]; then
        log_error "ArgoCD pods are not healthy"
        kubectl get pods -n argocd
        exit 1
    fi

    log_success "Security components validation passed"
}

validate_network_policies() {
    log_info "Validating network policies..."

    # Check if network policies exist
    local network_policies=$(kubectl get networkpolicies --all-namespaces --no-headers | wc -l)
    if [ "$network_policies" -eq 0 ]; then
        log_warn "No network policies found"
    else
        log_success "Found $network_policies network policies"
    fi

    # Check default deny policies
    local default_deny=$(kubectl get networkpolicies --all-namespaces --no-headers | grep "default-deny" | wc -l)
    if [ "$default_deny" -eq 0 ]; then
        log_warn "No default-deny network policies found"
    fi
}

validate_pod_security() {
    log_info "Validating pod security..."

    # Check for privileged pods
    local privileged_pods=$(kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].securityContext.privileged}{"\n"}{end}' | grep -c "true" || true)
    if [ "$privileged_pods" -gt 0 ]; then
        log_warn "Found $privileged_pods privileged pods"
    fi

    # Check for root containers
    local root_containers=$(kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].securityContext.runAsUser}{"\n"}{end}' | grep -c "0" || true)
    if [ "$root_containers" -gt 0 ]; then
        log_warn "Found $root_containers root containers"
    fi

    # Check for missing security contexts
    local pods_without_security_context=$(kubectl get pods --all-namespaces --no-headers | wc -l)
    local pods_with_security_context=$(kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.securityContext}{"\n"}{end}' | grep -c -v $'\t$' || true)

    if [ "$pods_with_security_context" -lt "$pods_without_security_context" ]; then
        log_warn "Some pods are missing security contexts"
    fi
}

validate_kops_cluster() {
    log_info "Validating kops cluster configuration..."

    if ! kops validate cluster --name "$CLUSTER_NAME" --wait 30s; then
        log_error "kops cluster validation failed"
        exit 1
    fi

    log_success "kops cluster validation passed"
}

generate_report() {
    log_info "Generating validation report..."

    local report_file="validation-report-$(date +%Y%m%d-%H%M%S).txt"

    {
        echo "Aegis Cluster Validation Report"
        echo "Generated: $(date)"
        echo "Cluster: $CLUSTER_NAME"
        echo "========================================"
        echo ""
        echo "Cluster Info:"
        kubectl cluster-info
        echo ""
        echo "Node Status:"
        kubectl get nodes
        echo ""
        echo "Pod Status Summary:"
        kubectl get pods --all-namespaces --no-headers | awk '{print $4}' | sort | uniq -c
        echo ""
        echo "Security Components Status:"
        echo "ArgoCD:"
        kubectl get pods -n argocd --no-headers | wc -l
        echo "Istio:"
        kubectl get pods -n istio-system --no-headers | wc -l
        echo "Kyverno:"
        kubectl get pods -n kyverno --no-headers | wc -l
        echo ""
        echo "Network Policies:"
        kubectl get networkpolicies --all-namespaces --no-headers | wc -l
        echo ""
        echo "Kyverno Policy Reports:"
        kubectl get policyreports --all-namespaces --no-headers | wc -l
    } > "$report_file"

    log_success "Report generated: $report_file"
}

main() {
    log_info "Starting Aegis cluster validation..."

    check_prerequisites
    validate_cluster_connectivity
    validate_cluster_health
    validate_security_components
    validate_network_policies
    validate_pod_security
    validate_kops_cluster
    generate_report

    log_success "Cluster validation completed successfully!"
}

# Run main function
main "$@"
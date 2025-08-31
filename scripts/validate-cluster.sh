#!/bin/bash
# Comprehensive Cluster Validation Script
# Validates security posture, policies, and configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-aegis-cluster}"
EXPECTED_NAMESPACES=("default" "kube-system" "istio-system" "cert-manager" "argocd" "kyverno" "monitoring")

echo -e "${BLUE}=== Aegis Cluster Validation ===${NC}"
echo "Validating cluster: $CLUSTER_NAME"
echo

# Function to check command availability
check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo -e "${RED}❌ $1 is not available${NC}"
        return 1
    else
        echo -e "${GREEN}✅ $1 is available${NC}"
        return 0
    fi
}

# Function to validate namespace exists
validate_namespace() {
    local ns=$1
    if kubectl get namespace "$ns" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Namespace $ns exists${NC}"
        return 0
    else
        echo -e "${RED}❌ Namespace $ns does not exist${NC}"
        return 1
    fi
}

# Function to validate PSA labels
validate_psa_labels() {
    local ns=$1
    local enforce_level
    enforce_level=$(kubectl get namespace "$ns" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "")

    if [ -n "$enforce_level" ]; then
        echo -e "${GREEN}✅ PSA enforce level for $ns: $enforce_level${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  No PSA labels found for $ns${NC}"
        return 1
    fi
}

# Function to validate Kyverno policies
validate_kyverno_policies() {
    local policy_count
    policy_count=$(kubectl get clusterpolicies -o json | jq '.items | length' 2>/dev/null || echo "0")

    if [ "$policy_count" -gt 0 ]; then
        echo -e "${GREEN}✅ $policy_count Kyverno policies found${NC}"
        return 0
    else
        echo -e "${RED}❌ No Kyverno policies found${NC}"
        return 1
    fi
}

# Function to validate NetworkPolicies
validate_network_policies() {
    local ns=$1
    local policy_count
    policy_count=$(kubectl get networkpolicies -n "$ns" -o json | jq '.items | length' 2>/dev/null || echo "0")

    if [ "$policy_count" -gt 0 ]; then
        echo -e "${GREEN}✅ $policy_count NetworkPolicies in $ns${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  No NetworkPolicies in $ns${NC}"
        return 1
    fi
}

# Function to validate TLS certificates
validate_certificates() {
    local cert_count
    cert_count=$(kubectl get certificates -A -o json | jq '.items | length' 2>/dev/null || echo "0")

    if [ "$cert_count" -gt 0 ]; then
        echo -e "${GREEN}✅ $cert_count certificates found${NC}"
        return 0
    else
        echo -e "${RED}❌ No certificates found${NC}"
        return 1
    fi
}

# Function to validate Istio configuration
validate_istio() {
    if kubectl get deployment istio-ingressgateway -n istio-system >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Istio ingress gateway found${NC}"
        return 0
    else
        echo -e "${RED}❌ Istio ingress gateway not found${NC}"
        return 1
    fi
}

# Function to validate ArgoCD
validate_argocd() {
    if kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
        echo -e "${GREEN}✅ ArgoCD server found${NC}"
        return 0
    else
        echo -e "${RED}❌ ArgoCD server not found${NC}"
        return 1
    fi
}

# Main validation logic
echo -e "${BLUE}1. Checking prerequisites...${NC}"
check_command kubectl
check_command jq
echo

echo -e "${BLUE}2. Validating cluster connectivity...${NC}"
if kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Cluster is accessible${NC}"
else
    echo -e "${RED}❌ Cannot connect to cluster${NC}"
    exit 1
fi
echo

echo -e "${BLUE}3. Validating namespaces...${NC}"
for ns in "${EXPECTED_NAMESPACES[@]}"; do
    validate_namespace "$ns"
done
echo

echo -e "${BLUE}4. Validating Pod Security Admission...${NC}"
for ns in "${EXPECTED_NAMESPACES[@]}"; do
    validate_psa_labels "$ns"
done
echo

echo -e "${BLUE}5. Validating Kyverno policies...${NC}"
validate_kyverno_policies
echo

echo -e "${BLUE}6. Validating NetworkPolicies...${NC}"
for ns in "${EXPECTED_NAMESPACES[@]}"; do
    validate_network_policies "$ns"
done
echo

echo -e "${BLUE}7. Validating certificates...${NC}"
validate_certificates
echo

echo -e "${BLUE}8. Validating Istio...${NC}"
validate_istio
echo

echo -e "${BLUE}9. Validating ArgoCD...${NC}"
validate_argocd
echo

echo -e "${BLUE}10. Running TLS validation...${NC}"
if [ -f "./scripts/tls-validation.sh" ]; then
    echo "Running TLS validation script..."
    bash ./scripts/tls-validation.sh
else
    echo -e "${YELLOW}⚠️  TLS validation script not found${NC}"
fi
echo

echo -e "${BLUE}=== Validation Complete ===${NC}"
echo -e "${GREEN}Cluster validation finished. Review any warnings or errors above.${NC}"
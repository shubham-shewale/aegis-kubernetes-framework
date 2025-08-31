#!/bin/bash

# Aegis Compliance Validation Script
# Validates security compliance and best practices

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OUTPUT_FILE="compliance-report-$(date +%Y%m%d-%H%M%S).json"

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

init_report() {
    cat > "$OUTPUT_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "compliance_checks": []
}
EOF
}

add_check_result() {
    local check_name="$1"
    local status="$2"
    local message="$3"
    local details="$4"

    # Add to JSON report
    jq --arg check "$check_name" \
       --arg status "$status" \
       --arg message "$message" \
       --arg details "$details" \
       '.compliance_checks += [{"name": $check, "status": $status, "message": $message, "details": $details}]' \
       "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
}

check_api_server_security() {
    log_info "Checking API server security..."

    # Check if anonymous auth is disabled
    local anonymous_auth=$(kubectl get configmap kube-apiserver -n kube-system -o jsonpath='{.data.*}' | grep -c "anonymous-auth.*false" || true)
    if [ "$anonymous_auth" -eq 0 ]; then
        add_check_result "api_server_anonymous_auth" "FAIL" "Anonymous authentication should be disabled" "Anonymous auth not explicitly disabled"
        log_error "Anonymous authentication not disabled"
    else
        add_check_result "api_server_anonymous_auth" "PASS" "Anonymous authentication is disabled" ""
        log_success "Anonymous authentication is disabled"
    fi

    # Check RBAC
    if kubectl api-versions | grep -q rbac; then
        add_check_result "rbac_enabled" "PASS" "RBAC is enabled" ""
        log_success "RBAC is enabled"
    else
        add_check_result "rbac_enabled" "FAIL" "RBAC should be enabled" "RBAC not found in API versions"
        log_error "RBAC is not enabled"
    fi
}

check_pod_security_standards() {
    log_info "Checking pod security standards..."

    # Check for privileged pods
    local privileged_pods=$(kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[].securityContext.privileged == true) | .metadata.name' | wc -l)
    if [ "$privileged_pods" -gt 0 ]; then
        add_check_result "privileged_pods" "WARN" "Privileged pods found" "$privileged_pods privileged pods detected"
        log_warn "Found $privileged_pods privileged pods"
    else
        add_check_result "privileged_pods" "PASS" "No privileged pods found" ""
        log_success "No privileged pods found"
    fi

    # Check for root containers
    local root_containers=$(kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[].securityContext.runAsUser == 0) | .metadata.name' | wc -l)
    if [ "$root_containers" -gt 0 ]; then
        add_check_result "root_containers" "WARN" "Root containers found" "$root_containers root containers detected"
        log_warn "Found $root_containers root containers"
    else
        add_check_result "root_containers" "PASS" "No root containers found" ""
        log_success "No root containers found"
    fi
}

check_network_policies() {
    log_info "Checking network policies..."

    local network_policies=$(kubectl get networkpolicies --all-namespaces --no-headers | wc -l)
    if [ "$network_policies" -eq 0 ]; then
        add_check_result "network_policies" "FAIL" "No network policies found" "Network policies are required for security"
        log_error "No network policies found"
    else
        add_check_result "network_policies" "PASS" "Network policies configured" "$network_policies network policies found"
        log_success "Found $network_policies network policies"
    fi

    # Check for default deny policies
    local default_deny=$(kubectl get networkpolicies --all-namespaces -o json | jq -r '.items[] | select(.spec.podSelector == {} and (.spec.policyTypes | contains(["Ingress"]))) | .metadata.name' | wc -l)
    if [ "$default_deny" -eq 0 ]; then
        add_check_result "default_deny_policies" "WARN" "No default deny policies found" "Consider implementing default deny policies"
        log_warn "No default deny policies found"
    else
        add_check_result "default_deny_policies" "PASS" "Default deny policies configured" "$default_deny default deny policies found"
        log_success "Found $default_deny default deny policies"
    fi
}

check_image_security() {
    log_info "Checking image security..."

    # Check for latest tag usage
    local latest_images=$(kubectl get pods --all-namespaces -o json | jq -r '.items[] | .spec.containers[].image' | grep -c ":latest$" || true)
    if [ "$latest_images" -gt 0 ]; then
        add_check_result "latest_image_tags" "WARN" "Latest image tags found" "$latest_images containers using latest tag"
        log_warn "Found $latest_images containers using latest tag"
    else
        add_check_result "latest_image_tags" "PASS" "No latest image tags found" ""
        log_success "No latest image tags found"
    fi

    # Check for image pull policy
    local always_pull=$(kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[].imagePullPolicy == "Always") | .metadata.name' | wc -l)
    if [ "$always_pull" -eq 0 ]; then
        add_check_result "image_pull_policy" "WARN" "No Always image pull policy found" "Consider using imagePullPolicy: Always"
        log_warn "No containers using Always image pull policy"
    else
        add_check_result "image_pull_policy" "PASS" "Image pull policy configured" "$always_pull containers using Always policy"
        log_success "Found $always_pull containers with Always pull policy"
    fi
}

check_secrets_management() {
    log_info "Checking secrets management..."

    # Check for plaintext secrets in environment variables
    local env_secrets=$(kubectl get pods --all-namespaces -o json | jq -r '.items[] | .spec.containers[].env[]? | select(.value and (.value | test("(?i)(password|secret|key|token)"))) | .name' | wc -l || true)
    if [ "$env_secrets" -gt 0 ]; then
        add_check_result "plaintext_secrets" "FAIL" "Plaintext secrets in environment variables" "$env_secrets environment variables contain sensitive data"
        log_error "Found $env_secrets environment variables with sensitive data"
    else
        add_check_result "plaintext_secrets" "PASS" "No plaintext secrets in environment" ""
        log_success "No plaintext secrets found in environment variables"
    fi

    # Check secret usage
    local secrets_used=$(kubectl get pods --all-namespaces -o json | jq -r '.items[] | .spec.containers[].envFrom[]?.secretRef.name' | wc -l || true)
    local secret_volumes=$(kubectl get pods --all-namespaces -o json | jq -r '.items[] | .spec.volumes[] | select(.secret) | .secret.secretName' | wc -l || true)
    local total_secrets=$((secrets_used + secret_volumes))

    if [ "$total_secrets" -gt 0 ]; then
        add_check_result "secret_usage" "PASS" "Secrets properly configured" "$total_secrets secrets in use"
        log_success "Found $total_secrets secrets in use"
    else
        add_check_result "secret_usage" "INFO" "No secrets found" "No secrets currently in use"
        log_info "No secrets found in use"
    fi
}

check_resource_limits() {
    log_info "Checking resource limits..."

    # Check pods without resource limits
    local pods_without_limits=$(kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[] | has("resources") | not) | .metadata.name' | wc -l || true)
    if [ "$pods_without_limits" -gt 0 ]; then
        add_check_result "resource_limits" "WARN" "Pods without resource limits" "$pods_without_limits pods missing resource limits"
        log_warn "Found $pods_without_limits pods without resource limits"
    else
        add_check_result "resource_limits" "PASS" "All pods have resource limits" ""
        log_success "All pods have resource limits configured"
    fi
}

check_kyverno_policies() {
    log_info "Checking Kyverno policies..."

    if kubectl get namespace kyverno &> /dev/null; then
        local policies=$(kubectl get clusterpolicies --no-headers | wc -l)
        if [ "$policies" -gt 0 ]; then
            add_check_result "kyverno_policies" "PASS" "Kyverno policies configured" "$policies policies found"
            log_success "Found $policies Kyverno policies"
        else
            add_check_result "kyverno_policies" "WARN" "No Kyverno policies found" "Consider implementing Kyverno policies"
            log_warn "No Kyverno policies found"
        fi

        # Check policy violations
        local violations=$(kubectl get policyreports --all-namespaces -o json | jq -r '.items[] | .summary.fail' | awk '{sum += $1} END {print sum}' || echo "0")
        if [ "$violations" -gt 0 ]; then
            add_check_result "policy_violations" "WARN" "Policy violations found" "$violations policy violations detected"
            log_warn "Found $violations policy violations"
        else
            add_check_result "policy_violations" "PASS" "No policy violations" ""
            log_success "No policy violations found"
        fi
    else
        add_check_result "kyverno_policies" "FAIL" "Kyverno not installed" "Kyverno is required for policy enforcement"
        log_error "Kyverno is not installed"
    fi
}

generate_summary() {
    log_info "Generating compliance summary..."

    local total_checks=$(jq '.compliance_checks | length' "$OUTPUT_FILE")
    local passed_checks=$(jq '.compliance_checks[] | select(.status == "PASS") | .name' "$OUTPUT_FILE" | wc -l)
    local failed_checks=$(jq '.compliance_checks[] | select(.status == "FAIL") | .name' "$OUTPUT_FILE" | wc -l)
    local warn_checks=$(jq '.compliance_checks[] | select(.status == "WARN") | .name' "$OUTPUT_FILE" | wc -l)

    local compliance_score=$(( (passed_checks * 100) / total_checks ))

    jq --arg score "$compliance_score" \
       --arg total "$total_checks" \
       --arg passed "$passed_checks" \
       --arg failed "$failed_checks" \
       --arg warn "$warn_checks" \
       '.summary = {"compliance_score": ($score | tonumber), "total_checks": ($total | tonumber), "passed": ($passed | tonumber), "failed": ($failed | tonumber), "warnings": ($warn | tonumber)}' \
       "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"

    echo ""
    log_info "Compliance Summary:"
    echo "==================="
    echo "Total Checks: $total_checks"
    echo "Passed: $passed_checks"
    echo "Failed: $failed_checks"
    echo "Warnings: $warn_checks"
    echo "Compliance Score: ${compliance_score}%"
    echo ""
    log_info "Detailed report saved to: $OUTPUT_FILE"
}

main() {
    log_info "Starting Aegis compliance validation..."

    init_report

    check_api_server_security
    check_pod_security_standards
    check_network_policies
    check_image_security
    check_secrets_management
    check_resource_limits
    check_kyverno_policies

    generate_summary

    log_success "Compliance validation completed!"
}

# Run main function
main "$@"
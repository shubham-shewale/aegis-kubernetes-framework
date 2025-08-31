#!/bin/bash

# Certificate Rotation Automation for Aegis Framework
# This script monitors and rotates Kubernetes certificates

set -e

# Configuration
NAMESPACE="kube-system"
CERT_VALIDITY_DAYS=365
RENEWAL_THRESHOLD_DAYS=30
LOG_FILE="/var/log/aegis/cert-rotation.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# Check if certificate expires soon
check_cert_expiry() {
    local cert_name=$1
    local expiry_date

    # Get certificate expiry date
    expiry_date=$(kubectl get certificate "$cert_name" -n "$NAMESPACE" -o jsonpath='{.status.notAfter}' 2>/dev/null || echo "")

    if [ -z "$expiry_date" ]; then
        log "${YELLOW}Certificate $cert_name not found or not managed by cert-manager${NC}"
        return 1
    fi

    # Calculate days until expiry
    local expiry_epoch=$(date -d "$expiry_date" +%s)
    local current_epoch=$(date +%s)
    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))

    log "${BLUE}Certificate $cert_name expires in $days_until_expiry days${NC}"

    if [ "$days_until_expiry" -le "$RENEWAL_THRESHOLD_DAYS" ]; then
        log "${YELLOW}Certificate $cert_name needs renewal (expires in $days_until_expiry days)${NC}"
        return 0
    else
        log "${GREEN}Certificate $cert_name is valid (expires in $days_until_expiry days)${NC}"
        return 1
    fi
}

# Renew certificate
renew_certificate() {
    local cert_name=$1

    log "${BLUE}Renewing certificate: $cert_name${NC}"

    # Use cert-manager CLI to trigger renewal
    if command -v cmctl >/dev/null 2>&1; then
        log "Using cmctl to renew certificate..."
        cmctl renew "$cert_name" -n "$NAMESPACE"
    else
        log "Using kubectl cert-manager to renew certificate..."
        kubectl cert-manager renew "$cert_name" -n "$NAMESPACE"
    fi

    # Wait for renewal to complete
    log "Waiting for certificate renewal to complete..."
    kubectl wait --for=condition=Ready certificate/"$cert_name" -n "$NAMESPACE" --timeout=300s

    if [ $? -eq 0 ]; then
        log "${GREEN}Certificate $cert_name renewed successfully${NC}"
    else
        log "${RED}Failed to renew certificate $cert_name${NC}"
        return 1
    fi
}

# Check all certificates
check_all_certificates() {
    log "${BLUE}Checking all certificates for expiry...${NC}"

    # Get all certificates
    local certificates
    certificates=$(kubectl get certificates -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

    if [ -z "$certificates" ]; then
        log "${YELLOW}No certificates found in namespace $NAMESPACE${NC}"
        return
    fi

    local renewed_count=0

    for cert in $certificates; do
        if check_cert_expiry "$cert"; then
            if renew_certificate "$cert"; then
                ((renewed_count++))
            fi
        fi
    done

    log "${GREEN}Certificate check complete. Renewed $renewed_count certificates.${NC}"
}

# Validate certificate health
validate_certificates() {
    log "${BLUE}Validating certificate health...${NC}"

    # Check cert-manager status
    if ! kubectl get deployment cert-manager -n cert-manager >/dev/null 2>&1; then
        log "${RED}cert-manager not found. Installing...${NC}"
        # Install cert-manager if not present
        kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
        kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
    fi

    # Check for certificate issues
    local invalid_certs
    invalid_certs=$(kubectl get certificates -n "$NAMESPACE" -o jsonpath='{.items[?(@.status.conditions[?(@.type=="Ready")].status!="True")].metadata.name}' 2>/dev/null || echo "")

    if [ -n "$invalid_certs" ]; then
        log "${RED}Invalid certificates found: $invalid_certs${NC}"
        return 1
    else
        log "${GREEN}All certificates are valid${NC}"
    fi
}

# Setup certificate monitoring cron job
setup_monitoring() {
    log "${BLUE}Setting up certificate monitoring...${NC}"

    # Create monitoring script
    cat > /usr/local/bin/cert-monitor.sh << 'EOF'
#!/bin/bash
/usr/local/bin/cert-rotation.sh --check-all
EOF

    chmod +x /usr/local/bin/cert-monitor.sh

    # Add cron job for daily certificate checks
    if ! crontab -l | grep -q "cert-monitor"; then
        (crontab -l ; echo "0 2 * * * /usr/local/bin/cert-monitor.sh") | crontab -
        log "${GREEN}Certificate monitoring cron job added${NC}"
    else
        log "${BLUE}Certificate monitoring cron job already exists${NC}"
    fi
}

# Main function
main() {
    case "${1:-}" in
        --check-all)
            check_all_certificates
            ;;
        --validate)
            validate_certificates
            ;;
        --setup-monitoring)
            setup_monitoring
            ;;
        --help|*)
            echo "Usage: $0 [OPTION]"
            echo "Certificate rotation automation for Aegis Framework"
            echo ""
            echo "Options:"
            echo "  --check-all        Check and renew expiring certificates"
            echo "  --validate         Validate certificate health"
            echo "  --setup-monitoring Setup automated certificate monitoring"
            echo "  --help             Show this help message"
            ;;
    esac
}

# Run main function
main "$@"
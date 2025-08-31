#!/bin/bash
# TLS Validation Script for Aegis Framework
# Tests cross-cluster communication without -k flag using internal CA

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CA_CERT_PATH="/etc/ssl/certs/internal-ca.crt"
BACKEND_URL="https://backend-api.default.svc.cluster.local/health"
GATEWAY_URL="https://istio-ingressgateway.istio-system.svc.cluster.local"

echo -e "${BLUE}=== Aegis TLS Validation Test ===${NC}"
echo "Testing TLS connections without -k flag using internal CA"
echo

# Function to test TLS connection
test_tls_connection() {
    local url=$1
    local expected_code=$2
    local description=$3

    echo -e "${YELLOW}Testing: ${description}${NC}"
    echo "URL: $url"

    # Test with curl using CA certificate
    if response=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
                     --cacert "$CA_CERT_PATH" \
                     --connect-timeout 10 \
                     --max-time 30 \
                     "$url" 2>/dev/null); then

        http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
        body=$(echo "$response" | sed '/HTTP_CODE:/d')

        if [ "$http_code" = "$expected_code" ]; then
            echo -e "${GREEN}✅ SUCCESS: HTTP $http_code${NC}"
            echo "Response: $body"
        else
            echo -e "${RED}❌ FAILED: Expected HTTP $expected_code, got $http_code${NC}"
            echo "Response: $body"
            return 1
        fi
    else
        echo -e "${RED}❌ FAILED: Connection error${NC}"
        return 1
    fi

    echo
}

# Test 1: Backend API health endpoint
test_tls_connection "$BACKEND_URL" "200" "Backend API Health Check"

# Test 2: Gateway health endpoint (if available)
# test_tls_connection "$GATEWAY_URL/health" "200" "Gateway Health Check"

# Test 3: Certificate validation
echo -e "${YELLOW}Testing Certificate Details...${NC}"
if command -v openssl >/dev/null 2>&1; then
    echo "Certificate Subject:"
    openssl s_client -connect "backend-api.default.svc.cluster.local:443" \
                     -CAfile "$CA_CERT_PATH" \
                     -servername "backend-api.default.svc.cluster.local" \
                     </dev/null 2>/dev/null | \
    openssl x509 -noout -subject 2>/dev/null || echo "Could not retrieve certificate"

    echo
    echo "Certificate Issuer:"
    openssl s_client -connect "backend-api.default.svc.cluster.local:443" \
                     -CAfile "$CA_CERT_PATH" \
                     -servername "backend-api.default.svc.cluster.local" \
                     </dev/null 2>/dev/null | \
    openssl x509 -noout -issuer 2>/dev/null || echo "Could not retrieve certificate"
else
    echo "OpenSSL not available for certificate inspection"
fi

echo
echo -e "${BLUE}=== TLS Validation Complete ===${NC}"
echo -e "${GREEN}All tests passed! TLS is properly configured without -k.${NC}"
# Cross-Cluster Communication Troubleshooting Guide

This guide helps diagnose and resolve common issues with cross-cluster service communication in the Aegis framework.

## Quick Diagnosis

### 1. Run Automated Diagnostics

```bash
# Use the setup script for diagnostics
./examples/cross-cluster-communication/scripts/setup-cross-cluster.sh --validate

# Or run manual checks
kubectl config use-context cluster-a
kubectl get serviceentry -n istio-system
kubectl get virtualservices -n default
kubectl get certificates -A
```

### 2. Check Component Status

```bash
# Check Istio components
kubectl get pods -n istio-system
kubectl get mutatingwebhookconfigurations
kubectl get validatingwebhookconfigurations

# Check cert-manager
kubectl get pods -n cert-manager
kubectl get certificates -A

# Check Kyverno
kubectl get pods -n kyverno
kubectl get clusterpolicies
```

## Common Issues and Solutions

### Issue 1: DNS Resolution Failures

**Symptoms:**
```
curl: (6) Could not resolve host: backend-api.cluster-b.local
nslookup: backend-api.cluster-b.local: Name or service not known
```

**Root Causes:**
- DNS configuration missing
- Service entry not applied
- Gateway address incorrect

**Solutions:**

1. **Check DNS Configuration**
```bash
# Verify DNS entries
nslookup backend-api.cluster-b.local
nslookup cluster-b-gateway.aegis.local

# Check /etc/hosts (if using local DNS)
cat /etc/hosts | grep cluster-b
```

2. **Verify Service Entry**
```bash
# Check service entries
kubectl get serviceentry -n istio-system

# Describe service entry
kubectl describe serviceentry cluster-b-services -n istio-system

# Check endpoints
kubectl get serviceentry cluster-b-services -n istio-system -o yaml
```

3. **Update Gateway Addresses**
```yaml
# Update simple-federation.yaml with correct addresses
endpoints:
- address: "192.168.1.100"  # Replace with actual gateway IP
  ports:
    https: 443
```

4. **Test Local DNS**
```bash
# Test from within cluster
kubectl run dns-test --image=busybox --rm -it -- nslookup backend-api.cluster-b.local
```

### Issue 2: Certificate Validation Errors

**Symptoms:**
```
SSL certificate verify failed
curl: (60) SSL certificate problem: unable to get local issuer certificate
```

**Root Causes:**
- Certificates not issued
- Certificate expiry
- Incorrect certificate configuration

**Solutions:**

1. **Check Certificate Status**
```bash
# Check all certificates
kubectl get certificates -A

# Check specific certificate
kubectl describe certificate backend-api-cert -n default

# Check certificate events
kubectl get events -A | grep certificate
```

2. **Verify Certificate Details**
```bash
# Check certificate content
kubectl get secret backend-api-tls -n default -o yaml

# Decode certificate
kubectl get secret backend-api-tls -n default -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text
```

3. **Check cert-manager Status**
```bash
# Check cert-manager pods
kubectl get pods -n cert-manager

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check issuer status
kubectl get issuers -A
kubectl describe issuer letsencrypt-prod -n cert-manager
```

4. **Renew Certificates**
```bash
# Force certificate renewal
kubectl delete certificate backend-api-cert -n default
kubectl apply -f examples/cross-cluster-communication/shared/certificates/cross-cluster-certs.yaml
```

### Issue 3: Authorization Policy Denials

**Symptoms:**
```
RBAC: access denied
HTTP 403 Forbidden
```

**Root Causes:**
- Incorrect authorization policies
- Service account mismatch
- Principal format issues

**Solutions:**

1. **Check Authorization Policies**
```bash
# List all policies
kubectl get authorizationpolicy -A

# Describe specific policy
kubectl describe authorizationpolicy cross-cluster-access -n default
```

2. **Verify Service Accounts**
```bash
# Check service accounts
kubectl get serviceaccounts -n default

# Check service account secrets
kubectl get secrets -n default | grep frontend-sa
```

3. **Check Principal Format**
```bash
# Verify SPIFFE identity format
kubectl get serviceaccounts frontend-sa -n default -o yaml

# Check Istio proxy identity
kubectl exec -it deployment/frontend-app -n default -- \
  curl -s http://localhost:15000/config_dump | grep spiffe
```

4. **Update Authorization Policy**
```yaml
# Fix principal format
rules:
- from:
  - source:
      principals: ["cluster-a.local/ns/default/sa/frontend-sa"]  # Correct format
  to:
  - operation:
      hosts: ["backend-api.cluster-b.local"]
```

### Issue 4: Connection Timeouts

**Symptoms:**
```
Connection timed out
504 Gateway Timeout
```

**Root Causes:**
- Network connectivity issues
- Gateway misconfiguration
- Firewall rules blocking traffic

**Solutions:**

1. **Check Network Connectivity**
```bash
# Test basic connectivity
ping cluster-b-gateway.aegis.local

# Test port connectivity
telnet cluster-b-gateway.aegis.local 443
```

2. **Verify Gateway Configuration**
```bash
# Check gateway status
kubectl get gateways -n default

# Check gateway configuration
kubectl describe gateway backend-api-gateway -n default

# Check Istio ingress pods
kubectl get pods -l istio=ingressgateway -n istio-system
```

3. **Check Firewall Rules**
```bash
# AWS Security Groups
aws ec2 describe-security-groups --group-ids <security-group-id>

# Network ACLs
aws ec2 describe-network-acls --network-acl-ids <nacl-id>
```

4. **Test Local Service**
```bash
# Test service within cluster
kubectl run test --image=curlimages/curl --rm -it -- \
  curl -v http://backend-api.default.svc.cluster.local:8080/health
```

### Issue 5: mTLS Configuration Issues

**Symptoms:**
```
upstream connect error or disconnect/reset before headers
SSL handshake failure
```

**Root Causes:**
- mTLS mode mismatch
- Certificate issues
- Peer authentication problems

**Solutions:**

1. **Check Peer Authentication**
```bash
# Check peer authentication policies
kubectl get peerauthentication -A

# Describe mTLS policy
kubectl describe peerauthentication cross-cluster-mtls -n istio-system
```

2. **Verify mTLS Mode**
```bash
# Check destination rule
kubectl get destinationrules -n default

# Verify TLS mode
kubectl describe destinationrule cross-cluster-backend-policies -n default
```

3. **Check Certificate Provisioning**
```bash
# Verify certificates in pods
kubectl exec -it deployment/frontend-app -n default -- \
  ls -la /etc/istio/certs/

# Check certificate expiry
kubectl exec -it deployment/frontend-app -n default -- \
  openssl x509 -in /etc/istio/certs/cert-chain.pem -text | grep "Not After"
```

### Issue 6: Service Discovery Problems

**Symptoms:**
```
Service not found
503 Service Unavailable
```

**Root Causes:**
- Service entry misconfiguration
- Endpoint address incorrect
- Service not running

**Solutions:**

1. **Check Service Entries**
```bash
# List service entries
kubectl get serviceentry -n istio-system

# Check service entry configuration
kubectl describe serviceentry cluster-b-services -n istio-system
```

2. **Verify Endpoints**
```bash
# Check endpoint configuration
kubectl get serviceentry cluster-b-services -n istio-system -o yaml

# Test endpoint connectivity
curl -k https://cluster-b-gateway.aegis.local/health
```

3. **Check Service Status**
```bash
# Switch to cluster B
kubectl config use-context cluster-b

# Check service status
kubectl get services -n default
kubectl get endpoints -n default

# Check pod status
kubectl get pods -n default
kubectl describe pod backend-api-xxxxx -n default
```

## Advanced Troubleshooting

### 1. Istio Proxy Debugging

```bash
# Check Envoy configuration
kubectl exec -it deployment/istio-ingressgateway -n istio-system -- \
  pilot-agent request GET config_dump > config_dump.json

# Check proxy status
kubectl exec -it deployment/frontend-app -n default -- \
  curl -s http://localhost:15000/stats | grep backend-api

# Check proxy logs
kubectl logs -l istio=ingressgateway -n istio-system --tail=100
```

### 2. Certificate Chain Validation

```bash
# Extract certificate chain
kubectl get secret backend-api-tls -n default -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt
kubectl get secret backend-api-tls -n default -o jsonpath='{.data.tls\.crt}' | base64 -d > cert.crt

# Validate certificate chain
openssl verify -CAfile ca.crt cert.crt

# Check certificate details
openssl x509 -in cert.crt -text -noout
```

### 3. Network Packet Analysis

```bash
# Capture packets (requires privileged access)
kubectl run packet-capture --image=corfr/tcpdump --privileged -- \
  tcpdump -i eth0 -w /tmp/capture.pcap host cluster-b-gateway.aegis.local

# Analyze captured packets
kubectl cp packet-capture:/tmp/capture.pcap ./capture.pcap
tcpdump -r capture.pcap -A | grep -i "backend-api"
```

### 4. Performance Analysis

```bash
# Check connection statistics
kubectl exec -it deployment/istio-ingressgateway -n istio-system -- \
  pilot-agent request GET stats | grep backend-api

# Monitor latency
kubectl apply -f examples/cross-cluster-communication/shared/monitoring/latency-monitor.yaml

# Check circuit breaker status
kubectl get destinationrules -n default -o yaml | grep outlierDetection
```

## Automated Troubleshooting

### 1. Health Check Script

```bash
#!/bin/bash
# examples/cross-cluster-communication/scripts/health-check.sh

CLUSTERS=("cluster-a" "cluster-b")

for cluster in "${CLUSTERS[@]}"; do
  echo "=== Checking $cluster ==="
  kubectl config use-context "$cluster"
  
  # Check components
  kubectl get pods -n istio-system
  kubectl get certificates -A
  kubectl get serviceentry -n istio-system
  
  # Test connectivity
  kubectl run test-$cluster --image=curlimages/curl --rm -it -- \
    curl -k -s https://backend-api.cluster-b.local/health || echo "Connectivity test failed"
done
```

### 2. Diagnostic Collection

```bash
#!/bin/bash
# examples/cross-cluster-communication/scripts/collect-diagnostics.sh

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DIAG_DIR="diagnostics-$TIMESTAMP"
mkdir -p "$DIAG_DIR"

# Collect logs and configurations
kubectl get all -A > "$DIAG_DIR/cluster-resources.txt"
kubectl get serviceentry -n istio-system -o yaml > "$DIAG_DIR/service-entries.yaml"
kubectl get certificates -A -o yaml > "$DIAG_DIR/certificates.yaml"
kubectl logs -n istio-system deployment/istiod > "$DIAG_DIR/istio-logs.txt"

# Create diagnostic archive
tar -czf "$DIAG_DIR.tar.gz" "$DIAG_DIR"
echo "Diagnostics collected in $DIAG_DIR.tar.gz"
```

## Prevention Best Practices

### 1. Regular Health Checks

```bash
# Add to cron for daily checks
0 6 * * * /path/to/health-check.sh >> /var/log/cross-cluster-health.log 2>&1
```

### 2. Certificate Monitoring

```bash
# Monitor certificate expiry
kubectl apply -f examples/cross-cluster-communication/shared/certificates/cert-monitoring.yaml
```

### 3. Automated Testing

```bash
# Run tests after deployments
kubectl apply -f examples/cross-cluster-communication/cluster-a/manifests/test-connection.yaml
```

### 4. Alert Configuration

```yaml
# Prometheus alerting rules
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: cross-cluster-alerts
spec:
  groups:
  - name: cross-cluster
    rules:
    - alert: CrossClusterConnectivityDown
      expr: up{job="cross-cluster-health"} == 0
      for: 5m
      labels:
        severity: critical
```

## Getting Help

### 1. Check Documentation
- [Setup Guide](setup-guide.md)
- [Security Considerations](security-considerations.md)
- [Aegis Framework Docs](../../docs/)

### 2. Community Support
- GitHub Issues: Report bugs and request features
- GitHub Discussions: Ask questions and share experiences
- Documentation: Check for updates and additional examples

### 3. Professional Services
For enterprise deployments requiring additional support:
- Architecture review and optimization
- Performance tuning and scaling
- Security hardening and compliance
- 24/7 monitoring and support

## Summary

Most cross-cluster communication issues fall into these categories:

1. **DNS/Network Configuration** (40% of issues)
2. **Certificate Management** (30% of issues)
3. **Authorization Policies** (20% of issues)
4. **Service Discovery** (10% of issues)

Following this troubleshooting guide and implementing the automated checks will help prevent and quickly resolve most issues. Regular maintenance and monitoring are key to maintaining reliable cross-cluster communication.
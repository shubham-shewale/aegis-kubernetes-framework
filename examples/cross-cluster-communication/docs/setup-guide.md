# Cross-Cluster Communication Setup Guide

This guide provides step-by-step instructions for setting up secure cross-cluster service communication using the Aegis Kubernetes Framework examples.

## Prerequisites

### 1. Two Kubernetes Clusters
```bash
# Create two clusters using Aegis framework
export ENVIRONMENT=staging
export CLUSTER_NAME=cluster-a.aegis.local
export AWS_REGION=us-east-1
./aegis provision

export CLUSTER_NAME=cluster-b.aegis.local
export AWS_REGION=us-west-2
./aegis provision
```

### 2. Istio Service Mesh
```bash
# Install Istio on both clusters
istioctl install --set profile=demo -y

# Verify installation
kubectl get pods -n istio-system
```

### 3. cert-manager
```bash
# Install cert-manager on both clusters
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

# Verify installation
kubectl get pods -n cert-manager
```

### 4. DNS Configuration
Ensure you have DNS names configured for cross-cluster access:
- `cluster-a-gateway.aegis.local` → Cluster A load balancer
- `cluster-b-gateway.aegis.local` → Cluster B load balancer
- `backend-api.cluster-b.local` → Cluster B backend service

## Step-by-Step Setup

### Step 1: Configure kubectl Contexts

```bash
# Add cluster contexts (adjust as needed)
kubectl config rename-context cluster-a.aegis.local cluster-a
kubectl config rename-context cluster-b.aegis.local cluster-b

# Verify contexts
kubectl config get-contexts
```

### Step 2: Setup Cluster A

```bash
# Switch to cluster A
kubectl config use-context cluster-a

# Deploy frontend application
kubectl apply -f examples/cross-cluster-communication/cluster-a/apps/frontend-app.yaml

# Verify deployment
kubectl get deployments -n default
kubectl get services -n default
```

### Step 3: Setup Cluster B

```bash
# Switch to cluster B
kubectl config use-context cluster-b

# Deploy backend API
kubectl apply -f examples/cross-cluster-communication/cluster-b/apps/backend-api.yaml

# Verify deployment
kubectl get deployments -n default
kubectl get services -n default
```

### Step 4: Configure Cross-Cluster Certificates

```bash
# Apply certificate configuration to both clusters
kubectl config use-context cluster-a
kubectl apply -f examples/cross-cluster-communication/shared/certificates/cross-cluster-certs.yaml

kubectl config use-context cluster-b
kubectl apply -f examples/cross-cluster-communication/shared/certificates/cross-cluster-certs.yaml

# Verify certificates
kubectl get certificates -A
```

### Step 5: Configure Istio Federation

```bash
# Apply Istio federation configuration to both clusters
kubectl config use-context cluster-a
kubectl apply -f examples/cross-cluster-communication/shared/istio/simple-federation.yaml

kubectl config use-context cluster-b
kubectl apply -f examples/cross-cluster-communication/shared/istio/simple-federation.yaml

# Verify Istio configuration
kubectl get serviceentry -n istio-system
kubectl get virtualservices -n default
kubectl get destinationrules -n default
```

### Step 6: Update Gateway Addresses

Before testing, update the Istio configuration with actual gateway addresses:

```yaml
# In simple-federation.yaml, update these lines:
endpoints:
- address: cluster-b-gateway.aegis.local  # Replace with actual IP/DNS
  ports:
    https: 443
    http: 80
```

### Step 7: Test Cross-Cluster Communication

```bash
# Switch to cluster A
kubectl config use-context cluster-a

# Run connectivity test
kubectl apply -f examples/cross-cluster-communication/cluster-a/manifests/test-connection.yaml

# Check test results
kubectl logs pod/cross-cluster-test -n default

# Expected output:
# === Cross-Cluster Communication Test ===
# 1. Testing backend API health endpoint...
# ✅ Health check passed
# 2. Testing backend API data endpoint...
# ✅ API endpoint test passed
# === All tests completed ===
```

## Automated Setup

Use the provided setup script for automated deployment:

```bash
# Make script executable
chmod +x examples/cross-cluster-communication/scripts/setup-cross-cluster.sh

# Full automated setup
./examples/cross-cluster-communication/scripts/setup-cross-cluster.sh --full-setup

# Or step-by-step setup
./examples/cross-cluster-communication/scripts/setup-cross-cluster.sh --setup-cluster-a
./examples/cross-cluster-communication/scripts/setup-cross-cluster.sh --setup-cluster-b
./examples/cross-cluster-communication/scripts/setup-cross-cluster.sh --test
```

## Configuration Options

### Environment Variables

```bash
# Cluster contexts
export CLUSTER_A_CONTEXT="cluster-a"
export CLUSTER_B_CONTEXT="cluster-b"

# Gateway addresses
export CLUSTER_A_GATEWAY="cluster-a-gateway.aegis.local"
export CLUSTER_B_GATEWAY="cluster-b-gateway.aegis.local"
```

### Customizing Service Communication

#### 1. Adding New Services

```yaml
# Add new service entry in simple-federation.yaml
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: new-service-cluster-b
spec:
  hosts:
  - "new-service.cluster-b.local"
  ports:
  - number: 80
    name: http
    protocol: HTTP
  resolution: DNS
  endpoints:
  - address: cluster-b-gateway.aegis.local
```

#### 2. Modifying Authorization Policies

```yaml
# Update authorization policy for new service
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: cross-cluster-access
spec:
  rules:
  - from:
    - source:
        principals: ["cluster-a.local/*"]
    to:
    - operation:
        hosts: ["new-service.cluster-b.local"]
        methods: ["GET", "POST"]
```

#### 3. Custom Load Balancing

```yaml
# Add custom destination rule
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: custom-load-balancing
spec:
  host: "*.cluster-b.local"
  trafficPolicy:
    loadBalancer:
      simple: LEAST_REQUEST  # Alternative: ROUND_ROBIN, RANDOM
    connectionPool:
      http:
        maxRequestsPerConnection: 100
```

## Monitoring and Observability

### 1. Enable Telemetry

```bash
# Apply telemetry configuration
kubectl apply -f examples/cross-cluster-communication/shared/istio/telemetry.yaml
```

### 2. Monitor Cross-Cluster Traffic

```bash
# Check Istio metrics
kubectl get metrics -n istio-system

# View cross-cluster service entries
kubectl get serviceentry -n istio-system

# Monitor authorization policies
kubectl get authorizationpolicy -n default
```

### 3. Debug Communication Issues

```bash
# Check Envoy configuration
kubectl exec -it deployment/istio-ingressgateway -n istio-system -- pilot-agent request GET config_dump

# View Istio proxy logs
kubectl logs -l istio=ingressgateway -n istio-system

# Test connectivity from within cluster
kubectl run test --image=curlimages/curl --rm -it -- \
  curl -v https://backend-api.cluster-b.local/health
```

## Security Considerations

### 1. Certificate Management

- Certificates are automatically rotated every 90 days
- Monitor certificate expiry with the provided scripts
- Use Let's Encrypt for production certificates

### 2. Network Security

- All cross-cluster traffic is encrypted with mTLS
- Authorization policies enforce least privilege
- Network policies restrict pod-to-pod communication

### 3. Access Control

- Service-level authentication using SPIFFE identities
- Namespace-based isolation
- Audit logging for all cross-cluster requests

## Troubleshooting

### Common Issues

#### 1. DNS Resolution Failures

**Symptoms:**
```
curl: (6) Could not resolve host: backend-api.cluster-b.local
```

**Solutions:**
```bash
# Check DNS configuration
nslookup backend-api.cluster-b.local

# Verify service entry
kubectl get serviceentry -n istio-system

# Check Istio proxy status
kubectl get pods -l istio=ingressgateway -n istio-system
```

#### 2. Certificate Issues

**Symptoms:**
```
SSL certificate verify failed
```

**Solutions:**
```bash
# Check certificate status
kubectl get certificates -A

# Verify certificate details
kubectl describe certificate backend-api-cert -n default

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

#### 3. Authorization Failures

**Symptoms:**
```
RBAC: access denied
```

**Solutions:**
```bash
# Check authorization policies
kubectl get authorizationpolicy -n default

# Verify service account
kubectl get serviceaccounts -n default

# Check Istio proxy logs
kubectl logs -l istio=ingressgateway -n istio-system
```

#### 4. Connection Timeouts

**Symptoms:**
```
Connection timed out
```

**Solutions:**
```bash
# Check network policies
kubectl get networkpolicies -n default

# Verify gateway configuration
kubectl get gateways -n default

# Test local connectivity
kubectl run test --image=curlimages/curl --rm -it -- \
  curl -v http://backend-api.default.svc.cluster.local:8080/health
```

## Advanced Configuration

### Multi-Region Setup

```yaml
# For multi-region clusters
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: multi-region-services
spec:
  hosts:
  - "*.us-east.aegis.local"
  - "*.us-west.aegis.local"
  - "*.eu-central.aegis.local"
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  resolution: DNS
  endpoints:
  - address: us-east-gateway.aegis.local
    locality: us-east-1
  - address: us-west-gateway.aegis.local
    locality: us-west-2
  - address: eu-central-gateway.aegis.local
    locality: eu-central-1
```

### Service Mesh Expansion

```yaml
# For service mesh expansion across clusters
apiVersion: networking.istio.io/v1alpha3
kind: WorkloadEntry
metadata:
  name: external-service
spec:
  address: external-service.example.com
  ports:
    https: 443
  serviceAccount: external-sa
  locality: external
  weight: 100
```

## Performance Optimization

### 1. Connection Pooling

```yaml
# Optimize connection pooling
trafficPolicy:
  connectionPool:
    tcp:
      maxConnections: 100
      connectTimeout: 30s
    http:
      http1MaxPendingRequests: 10
      http2MaxRequests: 100
      maxRequestsPerConnection: 10
```

### 2. Circuit Breaker

```yaml
# Implement circuit breaker
trafficPolicy:
  outlierDetection:
    consecutive5xxErrors: 3
    interval: 30s
    baseEjectionTime: 30s
    maxEjectionPercent: 50
```

### 3. Load Balancing

```yaml
# Advanced load balancing
trafficPolicy:
  loadBalancer:
    consistentHash:
      httpHeaderName: x-user-id
```

## Next Steps

1. **Scale to Production**: Implement the patterns in your production environment
2. **Add Monitoring**: Integrate with your existing monitoring stack
3. **Automate Deployment**: Use GitOps for automated cross-cluster deployments
4. **Security Hardening**: Implement additional security measures as needed
5. **Performance Tuning**: Optimize for your specific workload requirements

This setup provides a solid foundation for secure, reliable cross-cluster service communication in the Aegis framework. Customize the configurations based on your specific requirements and security policies.
# Cross-Cluster Service Communication Examples

This directory contains practical examples of implementing secure cross-cluster service communication in the Aegis Kubernetes Framework using Istio service mesh federation.

## 📁 **Directory Structure**

```
examples/cross-cluster-communication/
├── README.md                           # This file
├── cluster-a/                         # Primary cluster configurations
│   ├── manifests/                     # Kubernetes manifests for cluster A
│   ├── scripts/                       # Setup scripts for cluster A
│   └── apps/                          # Sample applications
├── cluster-b/                         # Secondary cluster configurations
│   ├── manifests/                     # Kubernetes manifests for cluster B
│   ├── scripts/                       # Setup scripts for cluster B
│   └── apps/                          # Sample applications
├── shared/                            # Shared configurations
│   ├── istio/                        # Istio federation configs
│   ├── certificates/                  # Cross-cluster certificates
│   └── monitoring/                    # Cross-cluster monitoring
└── docs/                             # Detailed documentation
    ├── setup-guide.md                # Step-by-step setup
    ├── troubleshooting.md            # Common issues and solutions
    └── security-considerations.md    # Security implications
```

## 🚀 **Quick Start**

### **Prerequisites**
- Two Kubernetes clusters created with Aegis framework
- Istio service mesh installed on both clusters
- kubectl configured for both clusters
- DNS resolution between clusters (or load balancers)

### **Basic Setup**
```bash
# 1. Deploy sample applications
kubectl apply -f examples/cross-cluster-communication/cluster-a/apps/
kubectl apply -f examples/cross-cluster-communication/cluster-b/apps/

# 2. Configure Istio federation
kubectl apply -f examples/cross-cluster-communication/shared/istio/

# 3. Setup cross-cluster certificates
kubectl apply -f examples/cross-cluster-communication/shared/certificates/

# 4. Test communication
kubectl apply -f examples/cross-cluster-communication/cluster-a/manifests/test-connection.yaml
```

## 🎯 **Example Scenarios**

### **Scenario 1: Simple Service-to-Service Communication**

**Use Case**: Frontend service in Cluster A calls backend API in Cluster B

**Files**:
- `cluster-a/apps/frontend-app.yaml` - Frontend application
- `cluster-b/apps/backend-api.yaml` - Backend API service
- `shared/istio/simple-federation.yaml` - Basic federation config

**Test**:
```bash
# From cluster-a
kubectl run test --image=curlimages/curl --rm -it -- \
  curl -v http://backend-api.cluster-b.local/api/health
```

### **Scenario 2: Database Access Across Clusters**

**Use Case**: Application in Cluster A needs to access database in Cluster B

**Files**:
- `cluster-a/apps/app-with-db.yaml` - Application with DB access
- `cluster-b/apps/database.yaml` - Database service
- `shared/istio/database-access.yaml` - Secure DB access config

**Security Features**:
- Mutual TLS encryption
- Database-specific authorization policies
- Connection pooling and circuit breakers

### **Scenario 3: Microservices Mesh Across Clusters**

**Use Case**: Distributed microservices spanning multiple clusters

**Files**:
- `cluster-a/apps/microservice-a.yaml` - Service A
- `cluster-b/apps/microservice-b.yaml` - Service B
- `shared/istio/microservices-mesh.yaml` - Full mesh configuration

**Features**:
- Service discovery across clusters
- Load balancing between clusters
- Distributed tracing
- Fault tolerance

### **Scenario 4: Event-Driven Communication**

**Use Case**: Services communicate via events across clusters

**Files**:
- `cluster-a/apps/event-producer.yaml` - Event producer
- `cluster-b/apps/event-consumer.yaml` - Event consumer
- `shared/istio/event-mesh.yaml` - Event mesh configuration

## 🔧 **Implementation Details**

### **Istio Configuration**

#### **Service Entry for Remote Services**
```yaml
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: remote-cluster-services
spec:
  hosts:
  - "*.cluster-b.local"
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  resolution: DNS
  endpoints:
  - address: cluster-b-gateway.external-ip
    ports:
      https: 443
  location: MESH_EXTERNAL
```

#### **Virtual Service for Routing**
```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: cross-cluster-routing
spec:
  hosts:
  - "api.cluster-b.local"
  http:
  - route:
    - destination:
        host: api.cluster-b.local
        port:
          number: 443
    timeout: 30s
```

#### **Destination Rule for Traffic Policies**
```yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: cross-cluster-policies
spec:
  host: "*.cluster-b.local"
  trafficPolicy:
    tls:
      mode: MUTUAL
    loadBalancer:
      simple: ROUND_ROBIN
    connectionPool:
      http:
        maxRequestsPerConnection: 10
```

### **Security Configuration**

#### **Peer Authentication (mTLS)**
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: cross-cluster-mtls
spec:
  selector:
    matchLabels:
      security: cross-cluster
  mtls:
    mode: STRICT
```

#### **Authorization Policies**
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: cross-cluster-access
spec:
  selector:
    matchLabels:
      app: backend-api
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster-a.local/*"]
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/*"]
```

### **Certificate Management**

#### **Cross-Cluster Certificate**
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: cross-cluster-ca
spec:
  secretName: cross-cluster-ca-cert
  issuerRef:
    name: aegis-issuer
    kind: Issuer
  dnsNames:
  - "*.cluster-a.local"
  - "*.cluster-b.local"
  - "*.aegis.local"
```

## 📊 **Monitoring and Observability**

### **Cross-Cluster Metrics**
```yaml
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: cross-cluster-telemetry
spec:
  selector:
    matchLabels:
      security: cross-cluster
  metrics:
  - providers:
    - name: prometheus
    overrides:
    - match:
        metric: REQUEST_COUNT
      mode: CLIENT_AND_SERVER
```

### **Distributed Tracing**
```yaml
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: cross-cluster-tracing
spec:
  selector:
    matchLabels:
      app: cross-cluster-app
  tracing:
  - providers:
    - name: jaeger
    customTags:
      cluster: request.headers["x-cluster"]
```

## 🧪 **Testing the Implementation**

### **Automated Tests**
```bash
# Run cross-cluster connectivity tests
./examples/cross-cluster-communication/scripts/test-connectivity.sh

# Validate security policies
./examples/cross-cluster-communication/scripts/test-security.sh

# Performance benchmarking
./examples/cross-cluster-communication/scripts/benchmark.sh
```

### **Manual Testing**
```bash
# Test basic connectivity
kubectl run test-pod --image=busybox --rm -it -- \
  wget -qO- http://api.cluster-b.local/health

# Test mTLS
kubectl logs -n istio-system deployment/istiod | grep "mtls"

# Test authorization
kubectl describe authorizationpolicy cross-cluster-access
```

## 🔒 **Security Considerations**

### **Network Security**
- All cross-cluster traffic encrypted with mTLS
- Authorization policies enforce least privilege
- Network policies prevent unauthorized access

### **Certificate Security**
- Automated certificate rotation
- Certificate validation before communication
- Secure certificate distribution

### **Access Control**
- Service-level authentication
- Namespace-based isolation
- Audit logging for all cross-cluster traffic

## 📈 **Performance Optimization**

### **Traffic Optimization**
- Connection pooling for reduced latency
- Circuit breakers for fault tolerance
- Load balancing across clusters

### **Monitoring Optimization**
- Minimal overhead telemetry collection
- Efficient metric aggregation
- Alert thresholds for cross-cluster latency

## 🚨 **Troubleshooting**

### **Common Issues**

1. **DNS Resolution Failures**
   ```bash
   # Check service entries
   kubectl get serviceentry -A

   # Test DNS
   nslookup api.cluster-b.local
   ```

2. **Certificate Issues**
   ```bash
   # Check certificate status
   kubectl get certificates -A

   # Validate certificate chain
   openssl s_client -connect cluster-b-gateway:443 -showcerts
   ```

3. **Authorization Failures**
   ```bash
   # Check authorization policies
   kubectl get authorizationpolicy -A

   # Review istio-proxy logs
   kubectl logs -l istio=ingressgateway -n istio-system
   ```

## 📚 **Additional Resources**

- [Istio Multi-Cluster Documentation](https://istio.io/latest/docs/setup/install/multicluster/)
- [Cross-Cluster Service Mesh Patterns](https://istio.io/latest/blog/2021/multi-cluster-patterns/)
- [Certificate Management Best Practices](https://cert-manager.io/docs/)

## 🎯 **Next Steps**

1. **Customize for Your Environment**
   - Update DNS names and IP addresses
   - Modify security policies for your requirements
   - Configure monitoring to match your stack

2. **Scale to Production**
   - Implement high availability for gateways
   - Set up automated failover
   - Configure disaster recovery

3. **Advanced Features**
   - Implement service mesh expansion
   - Add multi-cluster canary deployments
   - Configure cross-cluster blue-green deployments

This example implementation provides a solid foundation for secure cross-cluster communication in the Aegis framework. Start with the basic scenarios and gradually adopt more complex patterns as your needs evolve. 🚀
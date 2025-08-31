# Kubernetes Manifests

This directory contains Kubernetes manifests for deploying security components and applications in the Aegis framework.

## Directories

- `argocd/`: ArgoCD installation and application manifests
- `istio/`: Istio service mesh configurations for zero trust networking
- `kyverno/`: Kyverno policies for security and compliance
- `trivy/`: Trivy scanner configurations for vulnerability scanning

## Security Components

### Istio Service Mesh
- Mutual TLS authentication (mTLS) enforced
- Gateway configuration for secure ingress
- Virtual services for application routing

### Kyverno Policies
- Image signature validation
- Pod security standards enforcement
- Host path restrictions
- Non-root user requirements

### Trivy Scanner
- Scheduled vulnerability scanning
- Secret detection
- Configuration auditing
- SARIF report generation

## Deployment

Apply manifests in order:
1. ArgoCD for GitOps management
2. Security components (Istio, Kyverno, Trivy)
3. Application manifests

```bash
kubectl apply -f argocd/
kubectl apply -f istio/
kubectl apply -f kyverno/
kubectl apply -f trivy/
```

## Customization

- Update image registries and tags as needed
- Modify Kyverno policies for your security requirements
- Configure Trivy scan schedules and severity levels
- Adjust Istio gateway hosts for your domain
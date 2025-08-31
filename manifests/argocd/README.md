# ArgoCD Configuration

This directory contains ArgoCD manifests for GitOps management of the Aegis Kubernetes Framework.

## Files

- `install.yaml`: ArgoCD installation manifest with security hardening
- `security-app.yaml`: Application manifest for managing security components

## Installation

1. Apply ArgoCD installation:
   ```bash
   kubectl apply -f install.yaml
   ```

2. Get initial admin password:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

3. Access ArgoCD UI:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```

4. Apply security application:
   ```bash
   kubectl apply -f security-app.yaml
   ```

## Security Features

- TLS encryption for ArgoCD server
- RBAC with least privilege
- Automated sync with drift detection
- Prune propagation for clean rollbacks

## Configuration

Update the `repoURL` in `security-app.yaml` to point to your Git repository.

## Multi-Cluster Support

For multi-cluster deployments, create separate ArgoCD instances or use ArgoCD ApplicationSets for cluster-specific applications.
# ArgoCD Deployment Project

This project deploys ArgoCD to the k3s cluster via GitLab CI/CD.

## Prerequisites

1. Infrastructure must be deployed first (use infrastructure-project)
2. GitLab must be running in the cluster
3. GitLab Runner must have RBAC permissions

## Pipeline

The pipeline triggers on commits to main or master branch:
- Installs ArgoCD using Helm
- Configures NGINX ingress
- Waits for ArgoCD to be ready

## Access ArgoCD

After deployment:
```bash
# Get the admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access UI
http://argocd.local
```

## Manifests

All ArgoCD manifests are in /manifests/argocd/

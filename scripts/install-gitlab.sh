#!/bin/bash
set -e

NAMESPACE="gitlab"
MANIFEST_DIR="$(dirname "$0")/../manifests/gitlab"

echo "Installing GitLab..."
helm repo add gitlab https://charts.gitlab.io
helm repo update

# Ensure clean slate
echo "Cleaning up any existing installation..."
helm uninstall gitlab -n $NAMESPACE --wait 2>/dev/null || true
kubectl delete secret gitlab-gitlab-runner-secret -n $NAMESPACE --ignore-not-found --wait=true
kubectl delete secret gitlab-runner-secret-v2 -n $NAMESPACE --ignore-not-found --wait=true
kubectl delete namespace $NAMESPACE --ignore-not-found --wait=true

# Recreate namespace fresh
echo "Creating namespace..."
kubectl create namespace $NAMESPACE
kubectl label namespace $NAMESPACE istio-injection=disabled --overwrite

echo "Creating custom runner secret (v2)..."
kubectl create secret generic gitlab-runner-secret-v2 \
  --namespace $NAMESPACE \
  --from-literal=runner-registration-token="ngRewSxAsxfs-LwHESp-" \
  --from-literal=runner-token=""

echo "Applying GitLab Runner RBAC..."
kubectl apply -f "$MANIFEST_DIR/../gitlab-runner/rbac.yaml"

echo "Installing GitLab Chart..."
# Rely entirely on values.yaml for secret creation to avoid conflicts
helm upgrade --install gitlab gitlab/gitlab \
  --namespace $NAMESPACE \
  --timeout 600s \
  -f "$MANIFEST_DIR/values.yaml"

echo "GitLab installation initiated."
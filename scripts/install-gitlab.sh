#!/bin/bash
set -e

NAMESPACE="gitlab"
MANIFEST_DIR="$(dirname "$0")/../manifests/gitlab"

echo "Installing GitLab..."
helm repo add gitlab https://charts.gitlab.io
helm repo update

kubectl create namespace $NAMESPACE || true

echo "Applying GitLab Runner RBAC..."
kubectl apply -f "$MANIFEST_DIR/../gitlab-runner/rbac.yaml"

echo "Installing GitLab Chart..."
helm upgrade --install gitlab gitlab/gitlab \
  --namespace $NAMESPACE \
  --timeout 600s \
  -f "$MANIFEST_DIR/values.yaml"

echo "GitLab installation initiated."
#!/bin/bash
set -e

NAMESPACE="gitlab"
MANIFEST_DIR="$(dirname "$0")/../manifests/gitlab"

echo "Installing GitLab..."
helm repo add gitlab https://charts.gitlab.io
helm repo update

kubectl create namespace $NAMESPACE || true

echo "Cleaning up potential runner secret conflicts..."
# Uninstall failed release if exists to clean up owned resources
helm uninstall gitlab -n $NAMESPACE --wait || true

# Explicitly delete the conflicting secret and wait for it to be gone
kubectl delete secret gitlab-gitlab-runner-secret -n $NAMESPACE --ignore-not-found || true

echo "Waiting for secret to be fully deleted..."
while kubectl get secret gitlab-gitlab-runner-secret -n $NAMESPACE >/dev/null 2>&1; do
  echo "Secret still exists, waiting..."
  sleep 2
done

echo "Manually creating runner secret with Helm metadata..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: gitlab-gitlab-runner-secret
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/managed-by: Helm
  annotations:
    meta.helm.sh/release-name: gitlab
    meta.helm.sh/release-namespace: $NAMESPACE
type: Opaque
stringData:
  runner-registration-token: "ngRewSxAsxfs-LwHESp-"
  runner-token: ""
EOF

echo "Applying GitLab Runner RBAC..."
kubectl apply -f "$MANIFEST_DIR/../gitlab-runner/rbac.yaml"

echo "Installing GitLab Chart..."
helm upgrade --install gitlab gitlab/gitlab \
  --namespace $NAMESPACE \
  --timeout 600s \
  -f "$MANIFEST_DIR/values.yaml"

echo "GitLab installation initiated."
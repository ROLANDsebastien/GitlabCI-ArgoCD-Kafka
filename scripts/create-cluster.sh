#!/bin/bash
set -e

MASTER_NAME="k3s-master"
W1_NAME="k3s-worker1"
W2_NAME="k3s-worker2"

echo "Creating VMs..."

echo "Creating master VM..."
multipass launch --name $MASTER_NAME --cpus 1 --memory 2G --disk 10G

echo "Creating worker 1 VM..."
multipass launch --name $W1_NAME --cpus 4 --memory 8G --disk 20G

echo "Creating worker 2 VM..."
multipass launch --name $W2_NAME --cpus 4 --memory 8G --disk 20G

echo "All VMs created successfully!"

echo "Waiting for VMs to settle..."
sleep 20

echo "Installing k3s on master (tainted)..."
multipass exec $MASTER_NAME -- bash -c "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=\"v1.31.5+k3s1\" sh -s - --disable=traefik --disable=servicelb --node-taint CriticalAddonsOnly=true:NoExecute"

MASTER_IP=$(multipass info $MASTER_NAME --format json | jq -r ".info[\"$MASTER_NAME\"].ipv4[0]")
NODE_TOKEN=$(multipass exec $MASTER_NAME -- sudo cat /var/lib/rancher/k3s/server/node-token)

echo "Joining worker 1..."
multipass exec $W1_NAME -- bash -c "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=\"v1.31.5+k3s1\" K3S_URL=https://$MASTER_IP:6443 K3S_TOKEN=$NODE_TOKEN sh -"

echo "Joining worker 2..."
multipass exec $W2_NAME -- bash -c "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=\"v1.31.5+k3s1\" K3S_URL=https://$MASTER_IP:6443 K3S_TOKEN=$NODE_TOKEN sh -"

echo "Configuring kubeconfig..."
mkdir -p ~/.kube
multipass exec $MASTER_NAME -- sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/config
sed -i '' "s/127.0.0.1/$MASTER_IP/" ~/.kube/config
chmod 600 ~/.kube/config

echo "Waiting for cluster to be ready..."
sleep 10
kubectl wait --for=condition=ready node --all --timeout=120s

echo "Installing NGINX Ingress Controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
kubectl create namespace ingress-nginx || true

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --version 4.11.3 \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --set controller.service.nodePorts.https=30443 \
  --set controller.ingressClassResource.default=true \
  --wait --timeout 300s

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

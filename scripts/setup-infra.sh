#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Step 1: Creating Cluster + NGINX Ingress..."
./create-cluster.sh

echo ""
echo "Step 2: Installing GitLab (this takes a while)..."
./install-gitlab.sh

echo ""
echo "Step 3: Updating /etc/hosts (requires sudo)..."
./update-hosts.sh

echo ""
echo "Step 4: Patching Internal DNS for GitLab..."
./patch-dns.sh

echo ""
echo "Step 5: Show Access Information..."
./show-info.sh

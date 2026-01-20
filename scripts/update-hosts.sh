#!/bin/bash

# Only runs on local dev environment (macOS/Linux)
if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux-gnu"* ]]; then
    DOMAINS="gitlab.local argocd.local kafka-ui.local dashboard.local"
    
    echo "Updating /etc/hosts (requires sudo)..."
    
    # Get Worker 1 IP
    W1_IP=$(multipass info k3s-worker1 --format json | jq -r ".info[\"k3s-worker1\"].ipv4[0]")
    
    if [ -z "$W1_IP" ] || [ "$W1_IP" == "null" ]; then
        echo "Error: Could not find Worker 1 IP. Skipping hosts update."
        exit 1
    fi

    # Clean old entries
    for domain in $DOMAINS; do
        sudo sed -i '' "/$domain/d" /etc/hosts
    done

    # Add new entries
    echo "$W1_IP $DOMAINS" | sudo tee -a /etc/hosts > /dev/null
    
    echo "Hosts updated: $W1_IP -> $DOMAINS"
else
    echo "Skipping hosts update (not on local macOS/Linux environment)."
fi


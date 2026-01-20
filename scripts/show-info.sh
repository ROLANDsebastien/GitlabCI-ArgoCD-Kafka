#!/bin/bash

# Namespaces
GITLAB_NS="gitlab"
ARGOCD_NS="argocd"
KAFKA_NS="kafka"

echo "===================================================="
echo "         CLUSTER ACCESS INFORMATION"
echo "===================================================="

# Get IPs
W1_IP=$(multipass info k3s-worker1 --format json 2>/dev/null | jq -r ".info[\"k3s-worker1\"].ipv4[0]" || echo "N/A")
W2_IP=$(multipass info k3s-worker2 --format json 2>/dev/null | jq -r ".info[\"k3s-worker2\"].ipv4[0]" || echo "N/A")

echo "Worker 1 IP: $W1_IP"
echo "Worker 2 IP: $W2_IP"
echo ""

# Hosts file suggestion
echo "--- /etc/hosts CONFIGURATION ---"
echo "Add this to your /etc/hosts file:"
if [ "$W1_IP" != "N/A" ]; then
    echo "$W1_IP gitlab.local argocd.local kafka-ui.local"
else
    echo "Error: Cannot determine worker IP addresses"
fi
echo ""

# GitLab Info
echo "--- GITLAB ---"
if kubectl get ns $GITLAB_NS >/dev/null 2>&1; then
    echo "URL: http://gitlab.local:30080"
    echo "User: root"
    PASS=$(kubectl get secret gitlab-gitlab-initial-root-password -n $GITLAB_NS -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
    echo "Password: ${PASS:-'Still generating or not found'}"
    
    # Check status
    WEBSERVICE_READY=$(kubectl get pods -n $GITLAB_NS -l app=webservice --no-headers 2>/dev/null | grep -c "Running" || true)
    if [ "$WEBSERVICE_READY" -ge 1 ]; then
        echo "Status: Running"
    else
        echo "Status: Starting up (this can take 5-10 minutes)"
    fi
else
    echo "Status: Not deployed yet"
fi
echo ""

# Argo CD Info
echo "--- ARGO CD ---"
if kubectl get ns $ARGOCD_NS >/dev/null 2>&1; then
    echo "URL: http://argocd.local:30080"
    echo "User: admin"
    PASS=$(kubectl -n $ARGOCD_NS get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
    echo "Password: ${PASS:-'Still generating or not found'}"
    
    # Check status
    SERVER_READY=$(kubectl get pods -n $ARGOCD_NS -l app.kubernetes.io/name=argocd-server --no-headers 2>/dev/null | grep -c "Running" || true)
    if [ "$SERVER_READY" -ge 1 ]; then
        echo "Status: Running"
    else
        echo "Status: Starting up"
    fi
else
    echo "Status: Not deployed yet"
fi
echo ""

# Kafka Info
echo "--- KAFKA ---"
if kubectl get ns $KAFKA_NS >/dev/null 2>&1; then
    echo "Bootstrap Service: my-cluster-kafka-bootstrap.$KAFKA_NS.svc.cluster.local:9092"
    echo "Kafka UI URL: http://kafka-ui.local:30080"
    
    KAFKA_STATUS=$(kubectl get kafka -n $KAFKA_NS my-cluster -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo 'NotFound')
    if [ "$KAFKA_STATUS" = "True" ]; then
        echo "Status: Ready"
    elif [ "$KAFKA_STATUS" = "NotFound" ]; then
        echo "Status: Deploying cluster"
    else
        echo "Status: Not ready yet"
    fi
else
    echo "Status: Not deployed yet"
fi

echo "===================================================="
echo ""
echo "NOTES:"
echo "* GitLab can take 5-10 minutes to be fully ready"
echo "* All services are accessible via NodePort 30080"
echo ""
echo "For all pods status: kubectl get pods -A"
echo "===================================================="

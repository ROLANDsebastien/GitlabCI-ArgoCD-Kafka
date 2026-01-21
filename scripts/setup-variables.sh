#!/bin/bash
set -e

# Configuration
GITLAB_URL="http://gitlab.local:30080"
# Use environment variable if present, otherwise fallback to default
PERSONAL_ACCESS_TOKEN="${GITLAB_PAT:-glpat-BootstrapAutoToken99}"
PROJECTS=("argocd-project" "kafka-project")

# Snyk Token - User should provide this or we use a placeholder for now
if [ -z "$SNYK_TOKEN" ]; then
    if [ -t 0 ]; then
        echo -n "Please enter your Snyk Token (leave empty to use 'placeholder'): "
        read -s SNYK_TOKEN
        echo ""
    else
        echo "Non-interactive shell detected, using 'placeholder' for SNYK_TOKEN"
    fi
    
    if [ -z "$SNYK_TOKEN" ]; then
        SNYK_TOKEN="placeholder"
    fi
fi

# SSH Key for cross-project access (Kafka to ArgoCD)
SSH_PRIVATE_KEY_PATH="$HOME/.ssh/id_rsa"
if [ ! -f "$SSH_PRIVATE_KEY_PATH" ]; then
    SSH_PRIVATE_KEY_PATH="$HOME/.ssh/id_ed25519"
fi

if [ ! -f "$SSH_PRIVATE_KEY_PATH" ]; then
    echo "Warning: No private SSH key found at $SSH_PRIVATE_KEY_PATH. Skipping SSH variable."
    SSH_PRIVATE_KEY=""
else
    echo "Using Private Key: $SSH_PRIVATE_KEY_PATH"
    SSH_PRIVATE_KEY=$(cat "$SSH_PRIVATE_KEY_PATH")
fi

gitlab_api() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    local response
    if [ -z "$data" ]; then
        response=$(curl --silent --write-out "HTTPSTATUS:%{http_code}" --header "PRIVATE-TOKEN: $PERSONAL_ACCESS_TOKEN" \
             --request "$method" "$GITLAB_URL/api/v4$endpoint")
    else
        response=$(curl --silent --write-out "HTTPSTATUS:%{http_code}" --header "PRIVATE-TOKEN: $PERSONAL_ACCESS_TOKEN" \
             --header "Content-Type: application/json" \
             --request "$method" --data "$data" "$GITLAB_URL/api/v4$endpoint")
    fi

    local status=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    local body=$(echo "$response" | sed -e 's/HTTPSTATUS:.*//')

    if [[ "$status" -lt 200 || "$status" -ge 300 ]]; then
        echo "Error: API call failed with status $status"
        echo "Endpoint: $endpoint"
        echo "Response: $body"
        return 1
    fi
    echo "$body"
}

set_variable() {
    local project_id=$1
    local key=$2
    local value=$3
    local protected=${4:-false}
    local masked=${5:-false}

    echo "Setting variable $key for project $project_id..."
    
    # Check if variable exists
    if gitlab_api GET "/projects/$project_id/variables/$key" > /dev/null 2>&1; then
        # Update existing variable
        gitlab_api PUT "/projects/$project_id/variables/$key" \
            "{\"value\": \"$value\", \"protected\": $protected, \"masked\": $masked}" > /dev/null
    else
        # Create new variable
        gitlab_api POST "/projects/$project_id/variables" \
            "{\"key\": \"$key\", \"value\": \"$value\", \"protected\": $protected, \"masked\": $masked}" > /dev/null
    fi
}

for PROJECT in "${PROJECTS[@]}"; do
    # Get project ID (URL encoded path)
    PROJECT_PATH="root/$PROJECT"
    # In a real script we might need to URL encode the path, but root%2Fproject-name works
    PROJECT_ID="root%2F$PROJECT"
    
    echo "Configuring variables for $PROJECT..."
    
    # Set SNYK_TOKEN
    set_variable "$PROJECT_ID" "SNYK_TOKEN" "$SNYK_TOKEN" false true
    
    # Set SSH_PRIVATE_KEY for kafka-project to allow it to push to argocd-project
    if [ "$PROJECT" == "kafka-project" ] && [ -n "$SSH_PRIVATE_KEY" ]; then
        # Encode SSH key in base64 to avoid JSON escaping issues
        SSH_PRIVATE_KEY_B64=$(echo "$SSH_PRIVATE_KEY" | base64)
        set_variable "$PROJECT_ID" "SSH_PRIVATE_KEY" "$SSH_PRIVATE_KEY_B64" false false
    fi
done

echo "Variables configured successfully."

echo "------------------------------------------------"
echo "Configuring ArgoCD Repository Secrets..."

# Define the repository secret for internal access
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: gitlab-repo-creds
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  url: http://gitlab-webservice-default.gitlab.svc.cluster.local:8181/root/kafka-project.git
  password: $PERSONAL_ACCESS_TOKEN
  username: root
EOF

echo "ArgoCD Repository Secrets configured."

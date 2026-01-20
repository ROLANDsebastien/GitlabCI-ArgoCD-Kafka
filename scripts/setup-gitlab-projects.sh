#!/bin/bash
set -e

# Configuration
GITLAB_URL="http://gitlab.local:30080"
GITLAB_NS="gitlab"
TOKEN_NAME="bootstrap-automation-token"
# Use environment variable if present, otherwise fallback to default
PERSONAL_ACCESS_TOKEN="${GITLAB_PAT:-glpat-BootstrapAutoToken99}"
SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"
PROJECTS=("argocd-project" "kafka-project")

# Root directory detection (one level up from scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Root Directory: $ROOT_DIR"
cd "$ROOT_DIR"

# Check gitlab.local connectivity with retry
echo "Checking connectivity to $GITLAB_URL..."
MAX_RETRIES=10
RETRY_COUNT=0
CONNECTED=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s --head --request GET "$GITLAB_URL" | grep -E "200 OK|302 Found" > /dev/null; then
        CONNECTED=true
        break
    fi
    echo "Waiting for $GITLAB_URL to respond (Attempt $((RETRY_COUNT+1))/$MAX_RETRIES)..."
    sleep 10
    RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ "$CONNECTED" = false ]; then
    echo "Error: Cannot reach $GITLAB_URL after $MAX_RETRIES attempts."
    echo "Debug info: curl -I $GITLAB_URL"
    curl -I "$GITLAB_URL" || true
    echo "Make sure you have added gitlab.local to your /etc/hosts file."
    exit 1
fi
echo "Connected to GitLab!"

# Check for SSH key
if [ ! -f "$SSH_KEY_PATH" ]; then
    SSH_KEY_PATH="$HOME/.ssh/id_ed25519.pub"
    if [ ! -f "$SSH_KEY_PATH" ]; then
        echo "Error: No public SSH key found."
        exit 1
    fi
fi
echo "Using SSH Key: $SSH_KEY_PATH"

echo "Waiting for GitLab Toolbox pod to be ready..."
kubectl -n $GITLAB_NS wait --for=condition=ready pod -l app=toolbox --timeout=300s
TOOLBOX_POD=$(kubectl -n $GITLAB_NS get pods -l app=toolbox -o jsonpath="{.items[0].metadata.name}")

echo "Generating Personal Access Token via GitLab Rails..."
RUBY_SCRIPT="
user = User.find_by_username('root')
pat = user.personal_access_tokens.find_by(name: '$TOKEN_NAME')
pat.destroy if pat
pat = user.personal_access_tokens.build(scopes: [:api], name: '$TOKEN_NAME', expires_at: 365.days.from_now)
pat.set_token('$PERSONAL_ACCESS_TOKEN')
pat.save!
"
kubectl -n $GITLAB_NS exec -i $TOOLBOX_POD -- gitlab-rails runner "$RUBY_SCRIPT"
echo "Token created."

echo "Waiting for gitlab webservice to be ready for API calls..."
kubectl -n $GITLAB_NS wait --for=condition=ready pod -l app=webservice --timeout=300s

gitlab_api() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    if [ -z "$data" ]; then
        curl --silent --fail --header "PRIVATE-TOKEN: $PERSONAL_ACCESS_TOKEN" \
             --request "$method" "$GITLAB_URL/api/v4$endpoint"
    else
        curl --silent --fail --header "PRIVATE-TOKEN: $PERSONAL_ACCESS_TOKEN" \
             --header "Content-Type: application/json" \
             --request "$method" --data "$data" "$GITLAB_URL/api/v4$endpoint"
    fi
}

echo "Uploading SSH Key..."
SSH_KEY_CONTENT=$(cat "$SSH_KEY_PATH")
# Ignore error if key already exists
gitlab_api POST "/user/keys" "{\"title\": \"Bootstrap Key $(date +%s)\", \"key\": \"$SSH_KEY_CONTENT\"}" || echo "SSH Key might already exist, skipping..."

echo "Creating and Pushing Projects..."

for PROJECT in "${PROJECTS[@]}"; do
    echo "------------------------------------------------"
    echo "Processing $PROJECT..."
    
    # 1. Create Project in GitLab (ignore error if exists)
    echo "Creating project '$PROJECT' in GitLab..."
    gitlab_api POST "/projects" "{\"name\": \"$PROJECT\", \"visibility\": \"public\"}" || echo "Project $PROJECT might already exist."
    
    # 2. Prepare Local Repo
    if [ -d "$PROJECT" ]; then
        cd "$PROJECT"
        
        echo "Copying shared manifests into repo..."
        cp -r "$ROOT_DIR/manifests" .
        
        if [ ! -d ".git" ]; then
            git init
            git branch -M main
        fi
        
        # Use HTTP for push to avoid SSH port issues
        REMOTE_URL="http://root:$PERSONAL_ACCESS_TOKEN@gitlab.local:30080/root/$PROJECT.git"
        git remote set-url origin "$REMOTE_URL" 2>/dev/null || git remote add origin "$REMOTE_URL"
        
        echo "Pushing code to $REMOTE_URL (masking token)..."
        git add .
        git commit -m "Bootstrap auto-commit with dependencies" || echo "Nothing to commit"
        
        git push -u origin main --force
        
        cd "$ROOT_DIR"
    else
        echo "Warning: Directory $PROJECT not found at $(pwd)/$PROJECT"
    fi
done


# GitLab CI + ArgoCD + Kafka GitOps

A GitOps infrastructure featuring GitLab CI, ArgoCD, and Apache Kafka running on a multi-node K3s cluster.

## 🚀 Quick Start

### 1. Infrastructure Provisioning
Create the K3s cluster and install GitLab CE (takes approximately 5-10 minutes).
```bash
bash scripts/setup-infra.sh
```

### 2. Configure Environment (Optional)
If you want to automate Snyk token configuration, export it before the next step:
```bash
export SNYK_TOKEN="your_snyk_token"
```

### 3. GitLab Project & Variable Configuration
This script creates projects, pushes code (with CI enabled), and automatically configures CI/CD variables (`SNYK_TOKEN` and `SSH_PRIVATE_KEY` for cross-project deployment).

```bash
bash scripts/setup-gitlab-projects.sh
```
*Note: The script will prompt you for a Snyk Token if not already exported. The SSH key is handled automatically using your local `~/.ssh/id_rsa` (encoded in base64).*

### 4. Run the Pipeline
1. Go to GitLab: http://gitlab.local:30080
2. Select a project (**argocd-project** or **kafka-project**).
3. Go to **Build > Pipelines**.
4. Click **Run pipeline** > **Run pipeline**.

## 🏗️ Architecture

- **Cluster**: K3s (1 Master, 2 Workers) powered by Multipass.
- **GitLab**: Central hub for source code and CI/CD (Exposed on port `30080`).
- **ArgoCD**: GitOps operator managing continuous deployments.
- **Kafka**: Strimzi Operator (KRaft mode) with Kafka UI for management.
- **Snyk**: Security scanning for IaC and Container vulnerabilities.

## 🔒 Security Integration

Both projects include automated security scanning:
- **Snyk IaC**: Scans Kubernetes manifests for misconfigurations
- **Snyk Container**: Scans Docker images for vulnerabilities
- **Log Reports**: Results are available directly in the GitLab Job Logs

## 📁 Project Structure

- `scripts/`: Provisioning and maintenance tools.
- `manifests/`: Kubernetes configurations (Helm values, YAML).
- `argocd-project/`: GitLab project for ArgoCD deployment and lifecycle.
- `kafka-project/`: GitLab project for Strimzi, Kafka Cluster, and Kafka UI.

## 🔗 Service Access

| Service | URL | Credentials |
|---------|-----|--------------|
| **GitLab** | http://gitlab.local:30080 | root / (see `show-info.sh`) |
| **ArgoCD** | http://argocd.local:30080 | admin / (see `show-info.sh`) |
| **Kafka UI** | http://kafka-ui.local:30080 | - |

## 🛠️ Maintenance

- **Get Access Info**: `bash scripts/show-info.sh`
- **Update Local DNS**: `sudo bash scripts/update-hosts.sh`
- **Full Cleanup**: `bash scripts/purge-vms.sh`

## 🔧 Troubleshooting

### push-to-argocd Stage Failed
This stage creates the ArgoCD application manifest. Common issues:
- **SSH_PRIVATE_KEY**: Missing or empty in GitLab CI/CD variables
- **SSH Key Setup**: Must generate key pair and add public key to GitLab Profile
- **GitLab Runner**: Cannot access internal GitLab service
- **Permissions**: Runner needs push access to argocd-project

**Quick Fix:**
```bash
# Generate SSH key
ssh-keygen -t rsa -b 4096 -C "gitlab-ci@gitlab.local"

# Add public key to GitLab Profile > SSH Keys
# Use private key content as SSH_PRIVATE_KEY variable
```

### Snyk Scans Failed
- **SNYK_TOKEN**: Ensure token is valid and has required permissions
- **Network**: Runner needs internet access to Snyk API
- **Docker**: Container scans require Docker-in-Docker service


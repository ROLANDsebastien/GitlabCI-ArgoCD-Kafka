# GitLab CI + ArgoCD + Kafka GitOps

A GitOps infrastructure featuring GitLab CI, ArgoCD, and Apache Kafka running on a multi-node K3s cluster.

## 🚀 Quick Start

### 1. Infrastructure Provisioning
Create the K3s cluster and install GitLab CE (takes approximately 5-10 minutes).
```bash
bash scripts/setup-infra.sh
```

### 2. GitLab Project Configuration
Automatically configure GitLab repositories, inject manifests, and trigger initial CI/CD pipelines.
```bash
bash scripts/setup-gitlab-projects.sh
```

## 🏗️ Architecture

- **Cluster**: K3s (1 Master, 2 Workers) powered by Multipass.
- **GitLab**: Central hub for source code and CI/CD (Exposed on port `30080`).
- **ArgoCD**: GitOps operator managing continuous deployments.
- **Kafka**: Strimzi Operator (KRaft mode) with Kafka UI for management.

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


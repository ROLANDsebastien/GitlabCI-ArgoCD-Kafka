# Kafka Deployment Project

This project deploys Apache Kafka (via Strimzi) and Kafka UI to the k3s cluster via GitLab CI/CD.

## Prerequisites

1. Infrastructure must be deployed first (use infrastructure-project)
2. GitLab must be running in the cluster
3. GitLab Runner must have RBAC permissions

## Pipeline

The pipeline triggers on commits to main or master branch:
- Stage 1: Deploy Strimzi Kafka Operator
- Stage 2: Deploy Kafka Cluster (KRaft mode)
- Stage 3: Deploy Kafka UI + Ingress

## Access Kafka UI

After deployment:
```bash
# Access UI
http://kafka-ui.local
```

## Kafka Bootstrap Service

Applications can connect to Kafka at:
```
my-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092
```

## Manifests

All Kafka manifests are in /manifests/kafka/:
- kafka-kraft.yaml: Kafka cluster definition
- kafka-ui-values.yaml: Kafka UI Helm values
- manual-ingress.yaml: Ingress for Kafka UI

# Kubernetes Manifests

This directory contains Kubernetes manifests for deploying the Inspector system.

## Files

- `namespace.yaml` - Creates the `inspector` namespace
- `github-credentials.yaml` - Secret template for GitHub and Docker registry credentials
- `builder-cronjob.yaml` - CronJob that builds repository images every 30 minutes

## Deployment

### Prerequisites

1. A Kubernetes cluster with kubectl configured
2. Docker daemon running on cluster nodes (for building images)
3. GitHub Personal Access Token with `repo` scope
4. Docker registry credentials (GHCR or other)

### Setup

1. **Create the namespace:**
   ```bash
   kubectl apply -f k8s/namespace.yaml
   ```

2. **Configure credentials:**
   
   Edit `k8s/github-credentials.yaml` and replace the placeholder values:
   - `REPLACE_WITH_GITHUB_TOKEN` - Your GitHub Personal Access Token
   - `REPLACE_WITH_DOCKER_USERNAME` - Your Docker registry username (e.g., GitHub username for GHCR)
   - `REPLACE_WITH_DOCKER_PASSWORD` - Your Docker registry password/token (e.g., GitHub PAT for GHCR)
   
   Apply the secret:
   ```bash
   kubectl apply -f k8s/github-credentials.yaml
   ```

3. **Build and push the builder image:**
   ```bash
   docker build -f Dockerfile.builder -t ghcr.io/imdevinc/inspector-builder:latest .
   docker push ghcr.io/imdevinc/inspector-builder:latest
   ```

4. **Deploy the CronJob:**
   ```bash
   kubectl apply -f k8s/builder-cronjob.yaml
   ```

### Verification

Check that the CronJob was created:
```bash
kubectl get cronjob -n inspector
```

Trigger a manual build (for testing):
```bash
kubectl create job -n inspector inspector-builder-manual --from=cronjob/inspector-builder
```

Watch the job:
```bash
kubectl get jobs -n inspector -w
```

View logs:
```bash
kubectl logs -n inspector -l component=builder --tail=100 -f
```

Check for images in your registry:
```bash
# List images (example for GHCR)
# Visit: https://github.com/ImDevinC?tab=packages
```

### Configuration

The CronJob runs every 30 minutes by default. To change the schedule, edit `builder-cronjob.yaml` and modify the `schedule` field using cron syntax.

Examples:
- Every hour: `0 * * * *`
- Every 15 minutes: `*/15 * * * *`
- Daily at 2 AM: `0 2 * * *`

After editing, reapply:
```bash
kubectl apply -f k8s/builder-cronjob.yaml
```

## Troubleshooting

### CronJob not running

Check CronJob status:
```bash
kubectl describe cronjob inspector-builder -n inspector
```

### Build failures

View logs from failed jobs:
```bash
kubectl logs -n inspector -l component=builder --previous
```

Common issues:
- GitHub credentials invalid: Verify secret values
- Docker push fails: Check registry credentials and permissions
- Build commands fail: Verify repository configuration in `config/repositories.yaml`

### Resource limits

If builds fail due to memory/CPU limits, adjust resources in `builder-cronjob.yaml`:
```yaml
resources:
  limits:
    memory: "4Gi"  # Increase from 2Gi
    cpu: "4000m"   # Increase from 2000m
```

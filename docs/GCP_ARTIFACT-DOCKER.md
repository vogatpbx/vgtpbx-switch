# GCP Artifact Registry - Docker Image Push Guide

## Prerequisites

- GCP project with Artifact Registry enabled
- Docker installed
- gcloud CLI configured

## Authentication

When using Docker on Linux with sudo, credentials are saved in root.

**Configure Docker authentication:**
```bash
gcloud auth configure-docker northamerica-northeast1-docker.pkg.dev
```

**If you get "unauthenticated" error:**
```bash
sudo gcloud auth configure-docker northamerica-northeast1-docker.pkg.dev
```

## Registry Configuration

```bash
REGISTRY="northamerica-northeast1-docker.pkg.dev/dev-vgtpbx/vgtpbx-switch-docker"
VERSION="v1.0.0"  # Use semantic versioning
```

## Build and Push Images

### 1. FreeSWITCH (vgtpbx-switch)

**Build:**
```bash
cd vgtpbx-switch
docker build -t vgtpbx-switch:latest .
```

**Tag:**
```bash
docker tag vgtpbx-switch:latest \
  northamerica-northeast1-docker.pkg.dev/dev-vgtpbx/vgtpbx-switch-docker/vgtpbx-switch:$VERSION

docker tag vgtpbx-switch:latest \
  northamerica-northeast1-docker.pkg.dev/dev-vgtpbx/vgtpbx-switch-docker/vgtpbx-switch:latest
```

**Push:**
```bash
docker push northamerica-northeast1-docker.pkg.dev/dev-vgtpbx/vgtpbx-switch-docker/vgtpbx-switch:$VERSION
docker push northamerica-northeast1-docker.pkg.dev/dev-vgtpbx/vgtpbx-switch-docker/vgtpbx-switch:latest
```

### 2. ESL Server (vgtpbx-eslserver)

**Clone and build:**
```bash
git clone https://github.com/vogatpbx/vogat-eslserver.git
cd vogat-eslserver
docker build -t vgtpbx-eslserver:latest .
```

**Tag:**
```bash
docker tag vgtpbx-eslserver:latest \
  northamerica-northeast1-docker.pkg.dev/dev-vgtpbx/vgtpbx-switch-docker/vgtpbx-eslserver:$VERSION

docker tag vgtpbx-eslserver:latest \
  northamerica-northeast1-docker.pkg.dev/dev-vgtpbx/vgtpbx-switch-docker/vgtpbx-eslserver:latest
```

**Push:**
```bash
docker push northamerica-northeast1-docker.pkg.dev/dev-vgtpbx/vgtpbx-switch-docker/vgtpbx-eslserver:$VERSION
docker push northamerica-northeast1-docker.pkg.dev/dev-vgtpbx/vgtpbx-switch-docker/vgtpbx-eslserver:latest
```

## Automated Script

**Use the provided script** [`push-to-gcp.sh`](../push-to-gcp.sh) in the repository root:

```bash
# Make executable (if not already)
chmod +x push-to-gcp.sh

# Push vgtpbx-switch with specific version
./push-to-gcp.sh v1.0.0

# Push as latest
./push-to-gcp.sh latest
```

**Note:** This script only pushes vgtpbx-switch. For vgtpbx-eslserver, build and push from its separate repository:

```bash
git clone https://github.com/vogatpbx/vogat-eslserver.git
cd vogat-eslserver

# Build
docker build -t vgtpbx-eslserver:latest .

# Tag and push
VERSION="v1.0.0"
REGISTRY="northamerica-northeast1-docker.pkg.dev/dev-vgtpbx/vgtpbx-switch-docker"
docker tag vgtpbx-eslserver:latest $REGISTRY/vgtpbx-eslserver:$VERSION
docker push $REGISTRY/vgtpbx-eslserver:$VERSION
```

## Verify Images in Registry

```bash
gcloud artifacts docker images list \
  northamerica-northeast1-docker.pkg.dev/dev-vgtpbx/vgtpbx-switch-docker
```

## Update Cloud Function

After pushing new versions, update the cloud function environment variables:

```bash
gcloud functions deploy switchProvisioning \
  --set-env-vars DOCKER_IMAGE=$REGISTRY/vgtpbx-switch:$VERSION \
  --set-env-vars DOCKER_IMAGE_ESL=$REGISTRY/vgtpbx-eslserver:$VERSION
```

## Troubleshooting

### Permission Denied
```bash
# Check authentication
gcloud auth list

# Re-authenticate
gcloud auth login
gcloud auth configure-docker northamerica-northeast1-docker.pkg.dev
```

### Image Too Large
```bash
# Check image size
docker images | grep vgtpbx

# Clean up unused layers
docker system prune -a
```

### Push Timeout
```bash
# Increase timeout
export DOCKER_CLIENT_TIMEOUT=300
export COMPOSE_HTTP_TIMEOUT=300
```

## Best Practices

1. **Use semantic versioning**: v1.0.0, v1.0.1, etc.
2. **Tag both version and latest**: Allows rollback and easy updates
3. **Push both images together**: Ensure compatibility
4. **Test locally first**: `docker run` before pushing
5. **Document breaking changes**: In commit messages and release notes

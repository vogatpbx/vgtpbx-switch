#!/bin/bash
# Build and push vgtpbx-switch image to GCP Artifact Registry
#
# Note: vogat-eslserver is in a separate repository
# Build and push it separately from: https://github.com/vogatpbx/vogat-eslserver

set -e

VERSION=${1:-latest}
REGISTRY="northamerica-northeast1-docker.pkg.dev/dev-vgtpbx/vgtpbx-switch-docker"

echo "========================================="
echo "Building vgtpbx-switch Docker Image"
echo "========================================="
docker build -t vgtpbx-switch:latest .

echo ""
echo "========================================="
echo "Tagging Image (version: $VERSION)"
echo "========================================="
docker tag vgtpbx-switch:latest $REGISTRY/vgtpbx-switch:$VERSION

echo ""
echo "========================================="
echo "Pushing vgtpbx-switch to GCP..."
echo "========================================="
docker push $REGISTRY/vgtpbx-switch:$VERSION

echo ""
echo "✅ SUCCESS! Image pushed to GCP Artifact Registry:"
echo ""
echo "  📦 $REGISTRY/vgtpbx-switch:$VERSION"
echo ""
echo "⚠️  Remember to also build and push vogat-eslserver:"
echo "    git clone https://github.com/vogatpbx/vogat-eslserver.git"
echo "    cd vogat-eslserver"
echo "    docker build -t vgtpbx-eslserver:latest ."
echo "    docker tag vgtpbx-eslserver:latest $REGISTRY/vgtpbx-eslserver:$VERSION"
echo "    docker push $REGISTRY/vgtpbx-eslserver:$VERSION"
echo ""
echo "To deploy on VM:"
echo "  VERSION=$VERSION docker-compose -f docker-compose.prod.yml up -d"
echo ""

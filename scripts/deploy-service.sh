#!/usr/bin/env bash
# deploy-service.sh — deploy a new container image to a Cloud Run service
#
# Usage:
#   ./scripts/deploy-service.sh <service-name> <image-tag> <environment> <gcp-project-id> [region]
#
# Example:
#   ./scripts/deploy-service.sh ai-test-assets-service sha-abc1234 test my-gcp-project

set -euo pipefail

SERVICE="${1:-}"
IMAGE_TAG="${2:-}"
ENVIRONMENT="${3:-}"
GCP_PROJECT_ID="${4:-}"
REGION="${5:-us-central1}"

if [[ -z "$SERVICE" || -z "$IMAGE_TAG" || -z "$ENVIRONMENT" || -z "$GCP_PROJECT_ID" ]]; then
  echo "Usage: $0 <service-name> <image-tag> <environment> <gcp-project-id> [region]"
  exit 1
fi

PREFIX="${ENVIRONMENT}-"
[[ "$ENVIRONMENT" == "production" ]] && PREFIX=""

CLOUD_RUN_SERVICE="${PREFIX}${SERVICE}"
REGISTRY="${REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/fsi-platform"
IMAGE="${REGISTRY}/${SERVICE}:${IMAGE_TAG}"

echo ""
echo "Deploying service"
echo "  Service     : $CLOUD_RUN_SERVICE"
echo "  Image       : $IMAGE"
echo "  Environment : $ENVIRONMENT"
echo ""

gcloud run services update-traffic "$CLOUD_RUN_SERVICE" \
  --region="$REGION" \
  --project="$GCP_PROJECT_ID" \
  --image="$IMAGE" \
  --to-latest

echo "Deploy complete: $CLOUD_RUN_SERVICE @ $IMAGE_TAG"

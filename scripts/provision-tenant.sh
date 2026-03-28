#!/usr/bin/env bash
# provision-tenant.sh — create a new Tenant database and Keycloak realm
#
# Usage:
#   ./scripts/provision-tenant.sh <tenant-id> <environment> <gcp-project-id>
#
# Example:
#   ./scripts/provision-tenant.sh acme-corp production my-gcp-project

set -euo pipefail

TENANT_ID="${1:-}"
ENVIRONMENT="${2:-}"
GCP_PROJECT_ID="${3:-}"

if [[ -z "$TENANT_ID" || -z "$ENVIRONMENT" || -z "$GCP_PROJECT_ID" ]]; then
  echo "Usage: $0 <tenant-id> <environment> <gcp-project-id>"
  exit 1
fi

if [[ ! "$ENVIRONMENT" =~ ^(dev|test|production)$ ]]; then
  echo "environment must be dev, test, or production"
  exit 1
fi

INSTANCE_PREFIX="${ENVIRONMENT}-"
[[ "$ENVIRONMENT" == "production" ]] && INSTANCE_PREFIX=""
SQL_INSTANCE="${INSTANCE_PREFIX}fsi-postgres"

echo ""
echo "Provisioning Tenant: $TENANT_ID"
echo "  Environment : $ENVIRONMENT"
echo "  GCP project : $GCP_PROJECT_ID"
echo "  Cloud SQL   : $SQL_INSTANCE"
echo ""

# ── Create tenant database in Cloud SQL ───────────────────────────────────────
DB_NAME="tenant_${TENANT_ID//-/_}"
echo "Creating database: $DB_NAME"

gcloud sql databases create "$DB_NAME" \
  --instance="$SQL_INSTANCE" \
  --project="$GCP_PROJECT_ID"

echo "  Database created: $DB_NAME"

# ── Run schema migrations for the new tenant DB ───────────────────────────────
# The migrate Cloud Run Job runs the golang-migrate binary against the new DB (ADR-0015).
echo "Triggering migration job for $DB_NAME..."

gcloud run jobs execute "ai-test-assets-service-migrate" \
  --region="${GCP_REGION:-us-central1}" \
  --project="$GCP_PROJECT_ID" \
  --args="--database=$DB_NAME" \
  --wait

echo "  Migrations applied"

echo ""
echo "Done! Tenant '$TENANT_ID' is provisioned in '$ENVIRONMENT'."
echo ""
echo "Next steps:"
echo "  1. Create a Keycloak realm for this tenant via the Keycloak Admin API"
echo "  2. Configure subdomain ${TENANT_ID}.fsi-platform.com in Cloud DNS"
echo "  3. Add tenant to Firebase Hosting rewrite rules"
echo ""

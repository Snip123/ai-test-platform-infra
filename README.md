# ai-test-platform-infra

Terraform infrastructure for the FSI EAM/CMMS platform.
Three environments — all Cloud Run services **scale to zero** (ADR-0010).

## Environments

| Environment | Deploy trigger | Min instances | Cloud SQL tier |
|-------------|----------------|--------------|----------------|
| `dev`       | Manual `terraform apply` | 0 | db-f1-micro |
| `test`      | Auto on `main` merge (GitHub Actions) | 0 | db-f1-micro |
| `production`| Gated on `v*.*.*` tag (manual approval) | 0 | db-g1-small |

## Prerequisites

1. GCP project with billing enabled
2. Create the Terraform state bucket (once per project):
   ```bash
   gsutil mb -p $GCP_PROJECT_ID gs://$GCP_PROJECT_ID-terraform-state
   gsutil versioning set on gs://$GCP_PROJECT_ID-terraform-state
   ```
3. Replace `REPLACE_WITH_GCP_PROJECT_ID` in all `backend.tf` files
4. Enable required APIs:
   ```bash
   gcloud services enable \
     run.googleapis.com \
     sqladmin.googleapis.com \
     artifactregistry.googleapis.com \
     secretmanager.googleapis.com \
     compute.googleapis.com \
     iam.googleapis.com \
     iamcredentials.googleapis.com \
     --project=$GCP_PROJECT_ID
   ```
5. Set up GitHub Workload Identity for each service repo (ADR-0013):
   ```bash
   cd ../ai-test-platform-standards
   ./scripts/setup-github-oidc.sh Snip123/ai-test-platform-infra $GCP_PROJECT_ID
   ```
   Then add the extra Terraform role to the infra service account:
   ```bash
   gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
     --member="serviceAccount:<SA_EMAIL>" \
     --role="roles/editor"
   ```

## Deploy an environment

```bash
cd environments/dev        # or test / production
cp terraform.tfvars.example terraform.tfvars
# fill in project_id, region etc.
terraform init
terraform plan
terraform apply
```

## Modules

| Module | Purpose |
|--------|---------|
| `modules/cloud-run-service` | Reusable Cloud Run service with scale-to-zero config |
| `modules/cloud-sql` | Shared PostgreSQL instance + platform databases |
| `modules/nats-vm` | NATS JetStream on e2-micro (always-free tier) |

## Add a new service

1. Add a `module "your-service"` block to the relevant `environments/*/main.tf`
2. Use `../../modules/cloud-run-service` with `min_instance_count = 0`
3. Run `terraform plan` to preview, `terraform apply` to deploy

## Provision a new Tenant

```bash
./scripts/provision-tenant.sh <tenant-id> <environment> $GCP_PROJECT_ID
```

## CI/CD

The `terraform.yml` reusable workflow in `ai-test-platform-standards` handles:
- PR → `terraform plan` (posted as PR comment)
- `main` merge → `terraform apply` on `environments/test`
- `v*.*.*` tag → `terraform apply` on `environments/production` (approval gate)

See ADR-0013 for the full CI/CD strategy.

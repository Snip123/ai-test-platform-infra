# ── DEV ENVIRONMENT ───────────────────────────────────────────────────────────
#
# Dev is LOCAL ONLY — docker-compose in ai-test-platform-standards.
# There is no cloud dev stack to provision. This keeps idle cost at $0.
#
#   cd ai-test-platform-standards && docker compose up -d
#
# This directory exists as a placeholder for the rare case a developer needs
# a personal cloud environment. If you need one:
#   1. Add a neon-environment module call below pointing at the test Neon project
#   2. Run: terraform init && terraform apply
#   3. Destroy when done: terraform destroy
#
# Cost: $0/month (nothing provisioned by default).
# ─────────────────────────────────────────────────────────────────────────────

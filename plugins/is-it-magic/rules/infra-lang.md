---
paths:
  - "**/*.tf"
  - "**/*.tfvars"
  - "**/terraform*"
---

# Terraform / HCL Rules

## Naming
- Resources: snake_case, descriptive (`resource_type.descriptive_name`)
- Variables: snake_case with clear purpose
- Outputs: snake_case matching the resource they expose

## Structure
- `modules/` — reusable modules
- `environments/` — env-specific configs (dev, staging, prod)
- One resource type per file (`networking.tf`, `compute.tf`, `storage.tf`)

## Practices
- Remote state backend (e.g. Azure Storage / S3); lock state files
- Use variables for anything environment-specific
- Tag all resources with: `project`, `environment`, `managed_by=terraform`
- Never hardcode secrets — reference them from a secrets manager (Key Vault / Secrets Manager)

## Safety
- `terraform fmt`, `validate`, and `plan` are fine to run locally (preview / pre-checks — `plan` does not mutate state).
- **`terraform apply` and `destroy` are not run from the dev machine by default** — infrastructure changes deploy via the CI workflow (e.g. GitHub Actions) under its own deploy identity. Prefer triggering the deploy workflow over a local apply.
- **Safety hatch:** if the user explicitly and unambiguously directs a local `apply`/`destroy`, treat that as authorisation — confirm once that they intend to run it locally (outside CI), then proceed. Never run `apply`/`destroy` locally on your own initiative or from a vague/implied request.
- Never commit credential files — keep them outside the repo.

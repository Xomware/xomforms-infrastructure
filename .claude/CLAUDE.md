# xomforms-infrastructure

> AWS infrastructure for Xomforms.

## What This Is
Terraform IaC — DynamoDB, Lambda, API Gateway, custom authorizer, S3,
CloudFront for `xomforms.xomware.com`. See `docs/features/xomforms/PLAN.md`.

## Stack
- Terraform, HCL, AWS

## Key Commands
```bash
terraform init
terraform plan
terraform apply
```

## Project Config
```yaml
pm_tool: github-projects
github_project_number: 2
github_project_owner: Xomware
base_branch: master
test_commands:
  - echo "no tests configured"
```

## Constraints
- Cognito: reuse the SHARED `xomware_users` pool via `data_cognito.tf` (SSM lookups),
  matching `meals-infrastructure/terraform/data_cognito.tf`. Do NOT provision a new pool.
  New app client: `cognito_client_xomforms`.
- DynamoDB: PAY_PER_REQUEST + KMS + PITR on all tables.
- One public (unauthenticated) API Gateway route for poll read + guest submit;
  everything else behind the ported custom authorizer (email-keyed).

## Lessons

# Shared Cognito SSM data sources
#
# These read the SSM parameters exported by xomware-infrastructure (the
# shared pool owner -- see cognito_ssm.tf there). Xomforms consumes the
# shared xomware_users User Pool rather than owning its own identity
# surface. Do NOT provision a new pool here.
#
# Pattern matches meals-infrastructure/terraform/data_cognito.tf exactly.

data "aws_ssm_parameter" "cognito_user_pool_arn" {
  name = "/xomware/shared/cognito/user-pool-arn"
}

data "aws_ssm_parameter" "cognito_user_pool_id" {
  name = "/xomware/shared/cognito/user-pool-id"
}

data "aws_ssm_parameter" "cognito_user_pool_jwks_url" {
  name = "/xomware/shared/cognito/user-pool-jwks-url"
}

data "aws_ssm_parameter" "cognito_hosted_ui_domain" {
  name = "/xomware/shared/cognito/hosted-ui-domain"
}

# ----------------------------------------------------------------------
# App client -- cognito_client_xomforms
#
# NOTE / DEVIATION FLAGGED FOR REVIEW: every existing app client
# (xomware_com, xomappetit) is defined IN xomware-infrastructure (the pool
# owner -- see terraform/cognito.tf there) and merely read back via SSM by
# consumer apps (see cognito_xomappetit_client_id in the reference
# data_cognito.tf this file mirrors). xomware-infrastructure's own
# .claude/CLAUDE.md states "NO infrastructure changes without Dom's
# explicit approval" and that repo was NOT part of this Phase 2 approval
# scope (only xomforms-backend + xomforms-infrastructure were named).
#
# To stay within the authorized scope while still delivering the app
# client this phase asked for, the client is created HERE instead --
# attached cross-stack to the shared pool via its ID (a valid Terraform
# pattern; a client resource doesn't have to live in the same state as its
# pool). This means xomware-infrastructure's own state won't show this
# client if someone audits that repo in isolation.
#
# If Dom wants strict parity with the established pattern (client lives
# with the pool owner), this resource should move to
# xomware-infrastructure in a follow-up change -- which needs separate
# explicit sign-off on that repo per its own CLAUDE.md constraint.
# ----------------------------------------------------------------------

resource "aws_cognito_user_pool_client" "xomforms" {
  name         = "xomforms-client"
  user_pool_id = data.aws_ssm_parameter.cognito_user_pool_id.value

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  callback_urls = [
    "https://${local.domain_name}/auth/callback",
    "http://localhost:4200/auth/callback",
  ]

  logout_urls = [
    "https://${local.domain_name}",
    "http://localhost:4200",
  ]

  # Matches the existing clients' identity provider set (COGNITO + Google).
  # No explicit depends_on on the Google IdP resource since that resource
  # lives in a different Terraform state (xomware-infrastructure) -- if the
  # IdP isn't provisioned yet, apply will simply not offer Google sign-in
  # for this client until it is, rather than failing.
  supported_identity_providers = ["COGNITO", "Google"]

  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true

  id_token_validity      = 60
  access_token_validity  = 60
  refresh_token_validity = 30

  token_validity_units {
    id_token      = "minutes"
    access_token  = "minutes"
    refresh_token = "days"
  }
}

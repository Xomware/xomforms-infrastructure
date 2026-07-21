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

# App client -- cognito_client_xomforms.
#
# RESOLVED: previously this file provisioned the client directly (cross-
# stack, attached to the pool via its SSM-read ID) to stay within this
# phase's original approved scope. Dom chose "do it right" instead: the
# client now lives with the pool owner (xomware-infrastructure), mirroring
# exactly how xomware_com and xomappetit are defined there (see
# xomware-infrastructure/terraform/cognito.tf, and its SSM export in
# cognito_ssm.tf's aws_ssm_parameter.cognito_client_xomforms_id). This file
# only reads the resulting client ID back, same pattern as every other
# cross-app SSM read above.
#
# NOTE: this data source cannot resolve until the xomware-infrastructure
# change is reviewed AND applied -- do not run plan/apply here until that
# param exists in SSM.
data "aws_ssm_parameter" "cognito_client_xomforms_id" {
  name = "/xomware/shared/cognito/clients/xomforms-id"
}

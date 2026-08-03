## API Gateway Account (account-level singleton)

resource "aws_api_gateway_account" "api_gateway_account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

#**********************
# API Gateway (via reusable module)
#**********************

locals {
  # `authorization` is carried through per-endpoint so the module can mix
  # auth types on one API: public routes stay NONE while authed routes use
  # the native COGNITO_USER_POOLS authorizer (see lambda.tf). The
  # module-level default is COGNITO_USER_POOLS (set on the module block
  # below); NONE endpoints override it.
  polls_endpoints = [
    for l in local.polls_lambdas : {
      name          = l.name
      path_part     = l.path_part
      http_method   = l.http_method
      invoke_arn    = aws_lambda_function.polls[l.name].invoke_arn
      authorization = l.authorization
    }
  ]

  responses_endpoints = [
    for l in local.responses_lambdas : {
      name          = l.name
      path_part     = l.path_part
      http_method   = l.http_method
      invoke_arn    = aws_lambda_function.responses[l.name].invoke_arn
      authorization = l.authorization
    }
  ]

  results_endpoints = [
    for l in local.results_lambdas : {
      name          = l.name
      path_part     = l.path_part
      http_method   = l.http_method
      invoke_arn    = aws_lambda_function.results[l.name].invoke_arn
      authorization = l.authorization
    }
  ]

  invites_endpoints = [
    for l in local.invites_lambdas : {
      name          = l.name
      path_part     = l.path_part
      http_method   = l.http_method
      invoke_arn    = aws_lambda_function.invites[l.name].invoke_arn
      authorization = l.authorization
    }
  ]
}

module "api" {
  source = "git::https://github.com/domgiordano/api-gateway-service.git?ref=v2.7.0"

  app_name      = var.app_name
  stage_name    = var.api_stage_name
  authorization = "COGNITO_USER_POOLS"
  cognito_user_pool_arns = [
    data.aws_ssm_parameter.cognito_user_pool_arn.value
  ]
  tags          = local.standard_tags
  allow_headers = local.api_allow_headers
  allow_origin  = var.cors_allowed_origins

  # Custom domain
  domain_name     = local.api_domain_name
  certificate_arn = aws_acm_certificate_validation.api.certificate_arn

  services = {
    polls     = { path_prefix = "polls", endpoints = local.polls_endpoints }
    responses = { path_prefix = "responses", endpoints = local.responses_endpoints }
    results   = { path_prefix = "results", endpoints = local.results_endpoints }
    invites   = { path_prefix = "invites", endpoints = local.invites_endpoints }
  }
}

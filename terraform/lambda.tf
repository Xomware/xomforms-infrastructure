########################################
# Xomforms API Lambdas -- one per handler in xomforms-backend/lambdas/.
#
# `authorization` on an endpoint is carried through to api_gateway.tf.
# Authed routes use the native COGNITO_USER_POOLS authorizer (validated
# directly by API Gateway against the shared xomware_users pool -- see
# data_cognito.tf and the module block in api_gateway.tf, matching
# meals-infrastructure). Public routes override to NONE.
#
# THREE public routes, not one, as the original plan phrasing said ("one
# public route for guest submit and poll read"). Flagged for Dom's review
# at this plan-review checkpoint:
#   1. polls/get       -- poll config for the respondent grid (per plan)
#   2. responses/submit-guest -- guest availability submit (per plan)
#   3. results/get-public     -- NEW, discovered during infra design
#
# Why #3 exists: a NONE-authorization API Gateway route never invokes the
# Cognito authorizer at all -- requestContext.authorizer is simply absent,
# regardless of whether the caller sent a valid token. That means a single
# results/get route CANNOT distinguish "the creator" from "a guest" while
# also being reachable by guests, which showResultsToRespondents=true is
# specifically meant to allow (guests, by design, never hold a JWT -- see
# the locked "guest = name-only, no Cognito signup" decision). Resolved by
# splitting into two lambdas/routes instead of gating a single route
# in-handler:
#   - results/get        (CUSTOM) -- creator's own dashboard view, always
#     allowed for that poll's creatorEmail, 403 for any other authed caller
#   - results/get-public  (NONE)  -- respondent-facing view (guests
#     included), allowed only when showResultsToRespondents=true
# This avoids duplicating JWT/JWKS verification logic inside a handler,
# which the COGNITO_USER_POOLS authorizer already owns.
########################################

locals {
  polls_lambdas = [
    {
      name          = "create"
      description   = "Creator builds a schedule poll (authed)"
      path_part     = "create"
      http_method   = "POST"
      authorization = "COGNITO_USER_POOLS"
    },
    {
      name          = "get"
      description   = "Fetch poll config for the respondent grid (public)"
      path_part     = "get"
      http_method   = "GET"
      authorization = "NONE"
    },
    {
      name          = "list"
      description   = "\"My polls\" via creator GSI (authed)"
      path_part     = "list"
      http_method   = "GET"
      authorization = "COGNITO_USER_POOLS"
    },
    # POST (not DELETE/PATCH) to match /polls/create and keep every mutating
    # route on one verb through the shared api-gateway-service module.
    {
      name          = "delete"
      description   = "Creator deletes a form + cascades its responses (authed)"
      path_part     = "delete"
      http_method   = "POST"
      authorization = "COGNITO_USER_POOLS"
    },
    {
      name          = "close"
      description   = "Creator closes or reopens a form via closeAt (authed)"
      path_part     = "close"
      http_method   = "POST"
      authorization = "COGNITO_USER_POOLS"
    },
    {
      name          = "update"
      description   = "Creator edits form settings -- edits allowed, results visibility (authed)"
      path_part     = "update"
      http_method   = "POST"
      authorization = "COGNITO_USER_POOLS"
    },
  ]

  invites_lambdas = [
    {
      name          = "send"
      description   = "Creator emails form invites via SES (authed)"
      path_part     = "send"
      http_method   = "POST"
      authorization = "COGNITO_USER_POOLS"
    },
    {
      name          = "list"
      description   = "Creator reads invite recipients + delivery status (authed)"
      path_part     = "list"
      http_method   = "GET"
      authorization = "COGNITO_USER_POOLS"
    },
  ]

  places_lambdas = [
    {
      name          = "suggest"
      description   = "Address autocomplete for in-person events (authed)"
      path_part     = "suggest"
      http_method   = "GET"
      authorization = "COGNITO_USER_POOLS"
    },
  ]

  responses_lambdas = [
    {
      name          = "submit"
      description   = "Authed respondent upsert, keyed by email"
      path_part     = "submit"
      http_method   = "POST"
      authorization = "COGNITO_USER_POOLS"
    },
    {
      name          = "submit-guest"
      description   = "Guest submit, keyed by guest#<uuid>; gated by guestAllowed"
      path_part     = "submit-guest"
      http_method   = "POST"
      authorization = "NONE"
    },
    {
      name          = "mine"
      description   = "Forms the caller has responded to, via respondentKey GSI (authed)"
      path_part     = "mine"
      http_method   = "GET"
      authorization = "COGNITO_USER_POOLS"
    },
    {
      # NONE so a guest can prefill/edit their own answer using the guestId
      # held in their browser. The handler still requires either a Cognito
      # identity or a matching guestId -- it never returns anyone else's row.
      name          = "get-mine"
      description   = "The caller's own response to one form, for prefill/edit"
      path_part     = "get-mine"
      http_method   = "GET"
      authorization = "NONE"
    },
    {
      name          = "claim"
      description   = "Re-key this browser's guest responses onto the signed-in account"
      path_part     = "claim"
      http_method   = "POST"
      authorization = "COGNITO_USER_POOLS"
    },
  ]

  # TWO results routes, corrected during infra design (see comment above):
  # a NONE-authorization API Gateway route never invokes the custom
  # authorizer at all, so a single public route has no way to distinguish
  # "the creator" from "a guest" -- there is no requestContext.authorizer
  # to inspect either way. Splitting into an authed creator-dashboard route
  # and a separate public route (gated purely by showResultsToRespondents,
  # same behavior for authed non-creator respondents and guests alike)
  # resolves this without needing to duplicate JWT/JWKS verification logic
  # inside the handler itself.
  results_lambdas = [
    {
      name          = "get"
      description   = "Creator's own results view -- always allowed for the poll's creatorEmail, 403 for anyone else"
      path_part     = "get"
      http_method   = "GET"
      authorization = "COGNITO_USER_POOLS"
    },
    {
      name          = "get-public"
      description   = "Respondent-facing results view (guests included) -- allowed only when showResultsToRespondents=true"
      path_part     = "get-public"
      http_method   = "GET"
      authorization = "NONE"
    },
  ]
}

resource "aws_lambda_function" "polls" {
  for_each         = { for lambda in local.polls_lambdas : lambda.name => lambda }
  function_name    = "${var.app_name}-polls-${each.value.name}"
  description      = each.value.description
  filename         = "./templates/lambda_stub.zip"
  source_code_hash = filebase64sha256("./templates/lambda_stub.zip")
  handler          = "handler.handler"
  layers           = [aws_lambda_layer_version.lambda_layer.arn]
  runtime          = var.lambda_runtime
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout
  role             = aws_iam_role.lambda_role.arn

  environment {
    variables = local.lambda_variables
  }

  tracing_config {
    mode = var.lambda_trace_mode
  }

  tags = merge(local.standard_tags, tomap({ "name" = "${var.app_name}-polls-${each.value.name}", "lambda_type" = "polls" }))

  lifecycle {
    ignore_changes = [
      description,
      filename,
      source_code_hash,
      layers
    ]
  }

  depends_on = [
    aws_iam_role_policy.lambda_role_policy,
    aws_iam_role.lambda_role
  ]
}

resource "aws_lambda_function" "responses" {
  for_each         = { for lambda in local.responses_lambdas : lambda.name => lambda }
  function_name    = "${var.app_name}-responses-${each.value.name}"
  description      = each.value.description
  filename         = "./templates/lambda_stub.zip"
  source_code_hash = filebase64sha256("./templates/lambda_stub.zip")
  handler          = "handler.handler"
  layers           = [aws_lambda_layer_version.lambda_layer.arn]
  runtime          = var.lambda_runtime
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout
  role             = aws_iam_role.lambda_role.arn

  environment {
    variables = local.lambda_variables
  }

  tracing_config {
    mode = var.lambda_trace_mode
  }

  tags = merge(local.standard_tags, tomap({ "name" = "${var.app_name}-responses-${each.value.name}", "lambda_type" = "responses" }))

  lifecycle {
    ignore_changes = [
      description,
      filename,
      source_code_hash,
      layers
    ]
  }

  depends_on = [
    aws_iam_role_policy.lambda_role_policy,
    aws_iam_role.lambda_role
  ]
}

resource "aws_lambda_function" "results" {
  for_each         = { for lambda in local.results_lambdas : lambda.name => lambda }
  function_name    = "${var.app_name}-results-${each.value.name}"
  description      = each.value.description
  filename         = "./templates/lambda_stub.zip"
  source_code_hash = filebase64sha256("./templates/lambda_stub.zip")
  handler          = "handler.handler"
  layers           = [aws_lambda_layer_version.lambda_layer.arn]
  runtime          = var.lambda_runtime
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout
  role             = aws_iam_role.lambda_role.arn

  environment {
    variables = local.lambda_variables
  }

  tracing_config {
    mode = var.lambda_trace_mode
  }

  tags = merge(local.standard_tags, tomap({ "name" = "${var.app_name}-results-${each.value.name}", "lambda_type" = "results" }))

  lifecycle {
    ignore_changes = [
      description,
      filename,
      source_code_hash,
      layers
    ]
  }

  depends_on = [
    aws_iam_role_policy.lambda_role_policy,
    aws_iam_role.lambda_role
  ]
}

#**********************
# Invites Lambdas
#**********************
resource "aws_lambda_function" "invites" {
  for_each         = { for lambda in local.invites_lambdas : lambda.name => lambda }
  function_name    = "${var.app_name}-invites-${each.value.name}"
  description      = each.value.description
  filename         = "./templates/lambda_stub.zip"
  source_code_hash = filebase64sha256("./templates/lambda_stub.zip")
  handler          = "handler.handler"
  layers           = [aws_lambda_layer_version.lambda_layer.arn]
  runtime          = var.lambda_runtime
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout
  role             = aws_iam_role.lambda_role.arn

  environment {
    variables = local.lambda_variables
  }

  tracing_config {
    mode = var.lambda_trace_mode
  }

  tags = merge(local.standard_tags, tomap({ "name" = "${var.app_name}-invites-${each.value.name}", "lambda_type" = "invites" }))

  lifecycle {
    ignore_changes = [
      description,
      filename,
      source_code_hash,
      layers
    ]
  }

  depends_on = [
    aws_iam_role_policy.lambda_role_policy,
    aws_iam_role.lambda_role
  ]
}

#**********************
# Places Lambdas
#**********************
resource "aws_lambda_function" "places" {
  for_each         = { for lambda in local.places_lambdas : lambda.name => lambda }
  function_name    = "${var.app_name}-places-${each.value.name}"
  description      = each.value.description
  filename         = "./templates/lambda_stub.zip"
  source_code_hash = filebase64sha256("./templates/lambda_stub.zip")
  handler          = "handler.handler"
  layers           = [aws_lambda_layer_version.lambda_layer.arn]
  runtime          = var.lambda_runtime
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout
  role             = aws_iam_role.lambda_role.arn

  environment {
    variables = local.lambda_variables
  }

  tracing_config {
    mode = var.lambda_trace_mode
  }

  tags = merge(local.standard_tags, tomap({ "name" = "${var.app_name}-places-${each.value.name}", "lambda_type" = "places" }))

  lifecycle {
    ignore_changes = [
      description,
      filename,
      source_code_hash,
      layers
    ]
  }

  depends_on = [
    aws_iam_role_policy.lambda_role_policy,
    aws_iam_role.lambda_role
  ]
}

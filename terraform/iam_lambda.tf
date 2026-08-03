# ============================================
# Shared assume role policy for Lambda
# ============================================

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# NOTE: the authorizer Lambda execution role was removed when authed routes
# moved to the native COGNITO_USER_POOLS authorizer -- there is no
# authorizer Lambda to run. API Gateway validates Cognito JWTs against the
# shared xomware_users pool directly (see data_cognito.tf, api_gateway.tf).

# ============================================
# API Lambda IAM Role (polls, responses, results)
# ============================================

data "aws_iam_policy_document" "api_lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com", "apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.app_name}-lambda-exec"
  tags               = merge(local.standard_tags, tomap({ "name" = "${var.app_name}-lambda-exec" }))
  assume_role_policy = data.aws_iam_policy_document.api_lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_role_policy" {
  # CloudWatch Logs
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:log-group:/aws/lambda/${var.app_name}*",
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:log-group:/aws/lambda/${var.app_name}*:*"
    ]
  }

  # KMS -- for DynamoDB encryption
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]
    resources = [
      aws_kms_key.web_app.arn
    ]
  }

  # Lambda -- invoke own functions
  statement {
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction",
      "lambda:GetFunction"
    ]
    resources = [
      "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:function:${var.app_name}*"
    ]
  }

  # API Gateway -- execute API
  statement {
    effect  = "Allow"
    actions = ["execute-api:Invoke"]
    resources = [
      "${module.api.rest_api_execution_arn}/*/*/*"
    ]
  }

  # X-Ray Tracing
  statement {
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets"
    ]
    resources = ["*"]
  }

  # DynamoDB -- scoped to app tables only
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchWriteItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable"
    ]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:table/${var.app_name}*",
      "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:table/${var.app_name}*/index/*"
    ]
  }

  # SES -- form-invite sends (see lambdas/invites_send). Scoped to the verified
  # xomforms identity and its configuration set, NOT ses:* on "*": a leaked or
  # buggy lambda must not be able to send as any other identity in the account.
  statement {
    effect = "Allow"
    actions = [
      "ses:SendEmail"
    ]
    resources = [
      "arn:aws:ses:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:identity/${local.ses_domain}",
      "arn:aws:ses:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:configuration-set/${aws_sesv2_configuration_set.xomforms.configuration_set_name}"
    ]
  }

  # Read the SES from-address + configuration-set names written by ses.tf.
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:parameter/${var.app_name}/ses/*"
    ]
  }
}

resource "aws_iam_role_policy" "lambda_role_policy" {
  name   = "${var.app_name}-lambda-role-policy"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_role_policy.json
}

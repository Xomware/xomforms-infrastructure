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

# ============================================
# Authorizer Lambda IAM Role
# Minimal permissions -- CloudWatch + X-Ray only. Unlike xomify's authorizer
# (which reads API_SECRET_KEY from SSM at runtime), the ported xomforms
# authorizer validates Cognito JWTs against a JWKS URL baked into its
# environment variables at deploy time (see locals.tf), so no runtime SSM
# access is needed.
# ============================================

resource "aws_iam_role" "authorizer_role" {
  name               = "${var.app_name}-authorizer-exec"
  tags               = merge(local.standard_tags, tomap({ "name" = "${var.app_name}-authorizer-exec" }))
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "authorizer_role_policy" {
  # CloudWatch Logs
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:log-group:/aws/lambda/${var.app_name}-authorizer",
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:log-group:/aws/lambda/${var.app_name}-authorizer:*"
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
}

resource "aws_iam_role_policy" "authorizer_role_policy" {
  name   = "${var.app_name}-authorizer-role-policy"
  role   = aws_iam_role.authorizer_role.id
  policy = data.aws_iam_policy_document.authorizer_role_policy.json
}

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
}

resource "aws_iam_role_policy" "lambda_role_policy" {
  name   = "${var.app_name}-lambda-role-policy"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_role_policy.json
}

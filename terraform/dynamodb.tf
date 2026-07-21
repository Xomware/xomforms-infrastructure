########################################
# 1. xomforms-polls
# PK: pollId
# GSI creatorEmail-createdAt-index: PK creatorEmail, SK createdAt -- "my polls"
########################################
resource "aws_dynamodb_table" "polls" {
  name           = "${var.app_name}-polls"
  billing_mode   = "PAY_PER_REQUEST"
  read_capacity  = 0
  write_capacity = 0
  hash_key       = "pollId"

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_alias.dynamodb.target_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  attribute {
    name = "pollId"
    type = "S"
  }

  attribute {
    name = "creatorEmail"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  # GSI: "my polls" -- list a creator's polls, newest first.
  global_secondary_index {
    name            = "creatorEmail-createdAt-index"
    hash_key        = "creatorEmail"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  tags = merge(local.standard_tags, tomap({ "name" = "${var.app_name}-polls" }))
}

########################################
# 2. xomforms-responses
# PK: pollId
# SK: respondentKey (email, or "guest#<uuid>")
# TTL: closeAt (epoch seconds, denormalized from the poll at submit time --
# see lambdas/common/responses_dynamo.py::upsert_response)
########################################
resource "aws_dynamodb_table" "responses" {
  name           = "${var.app_name}-responses"
  billing_mode   = "PAY_PER_REQUEST"
  read_capacity  = 0
  write_capacity = 0
  hash_key       = "pollId"
  range_key      = "respondentKey"

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_alias.dynamodb.target_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  attribute {
    name = "pollId"
    type = "S"
  }

  attribute {
    name = "respondentKey"
    type = "S"
  }

  ttl {
    attribute_name = "closeAt"
    enabled        = true
  }

  tags = merge(local.standard_tags, tomap({ "name" = "${var.app_name}-responses" }))
}

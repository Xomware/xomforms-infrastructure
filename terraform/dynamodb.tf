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
# GSI respondentKey-pollId-index: PK respondentKey, SK pollId -- powers
# "forms I filled out" on the dashboard, and the guest->account claim.
#
# NO TTL. Responses used to carry the poll's closeAt as a TTL attribute, so
# DynamoDB reaped them once a form closed. That was fine while responses were
# write-only, but participation history is now a product feature: respondents
# see the forms they answered and can edit their own response. Storage that
# garbage-collects itself cannot back either of those.
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

  global_secondary_index {
    name            = "respondentKey-pollId-index"
    hash_key        = "respondentKey"
    range_key       = "pollId"
    projection_type = "ALL"
  }

  tags = merge(local.standard_tags, tomap({ "name" = "${var.app_name}-responses" }))
}

# API Gateway ID -- published for reference/debugging, matching the
# xomify-infrastructure / meals-infrastructure convention. Xomforms has no
# third-party API secrets to store (no Spotify-style credentials).
resource "aws_ssm_parameter" "api_id" {
  name        = "/${var.app_name}/api/API_ID"
  description = "API Gateway ID"
  type        = "SecureString"
  value       = module.api.rest_api_id

  lifecycle { ignore_changes = [tags, tags_all] }
}

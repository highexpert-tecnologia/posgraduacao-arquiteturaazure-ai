# https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_secret

resource "github_actions_secret" "secret_sonar_token" {
  repository  = var.repository_name
  secret_name = "SONAR_TOKEN"
  value       = var.sonar_token
}

resource "github_actions_secret" "secret_sonar_project_key" {
  repository  = var.repository_name
  secret_name = "SONAR_PROJECT_KEY"
  value       = var.sonar_project_key
}

## Azure Login

resource "github_actions_secret" "secret_azure_client_id" {
  repository  = var.repository_name
  secret_name = "AZURE_CLIENT_ID"
  value       = var.azure_client_id
}

resource "github_actions_secret" "secret_azure_tenant_id" {
  repository  = var.repository_name
  secret_name = "AZURE_TENANT_ID"
  value       = var.azure_tenant_id
}

resource "github_actions_secret" "secret_azure_subscription_id" {
  repository  = var.repository_name
  secret_name = "AZURE_SUBSCRIPTION_ID"
  value       = var.azure_subscription_id
}

## OTel Observability

resource "github_actions_secret" "secret_otlp_honeycomb_headers" {
  count       = var.otlp_honeycomb_headers != null ? 1 : 0
  repository  = var.repository_name
  secret_name = "OTLP_HONEYCOMB_HEADERS"
  value       = var.otlp_honeycomb_headers
}

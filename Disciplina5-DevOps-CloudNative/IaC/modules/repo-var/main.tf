# https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_organization_variable

resource "github_actions_variable" "var_sonar_organization" {
  repository    = var.repository_name
  variable_name = "SONAR_ORGANIZATION"
  value         = var.sonar_organization
}

resource "github_actions_variable" "var_sonar_project_name" {
  repository    = var.repository_name
  variable_name = "SONAR_PROJECT_NAME"
  value         = var.sonar_project_name
}

resource "github_actions_variable" "var_deploy_target" {
  count         = var.deploy_target != null ? 1 : 0
  repository    = var.repository_name
  variable_name = "deploy_target"
  value         = var.deploy_target
}

resource "github_actions_variable" "var_container_registry" {
  count         = var.container_registry != null ? 1 : 0
  repository    = var.repository_name
  variable_name = "CONTAINER_REGISTRY"
  value         = var.container_registry
}

resource "github_actions_variable" "var_azure_acr_registry" {
  repository    = var.repository_name
  variable_name = "AZURE_ACR_REGISTRY"
  value         = var.azure_acr_registry
}

resource "github_actions_variable" "var_azure_acr_pull_identity_id" {
  repository    = var.repository_name
  variable_name = "AZURE_ACR_PULL_IDENTITY_ID"
  value         = var.azure_acr_pull_identity_id
}

resource "github_actions_variable" "var_azure_resource_group_name" {
  repository    = var.repository_name
  variable_name = "AZURE_RESOURCE_GROUP_NAME"
  value         = var.azure_resource_group_base
}

resource "github_actions_variable" "var_azure_acae_base" {
  repository    = var.repository_name
  variable_name = "AZURE_ACAE_BASE"
  value         = var.azure_acae_base
}

resource "github_actions_variable" "var_build_version" {
  count         = var.build_version != null ? 1 : 0
  repository    = var.repository_name
  variable_name = "BUILD_VERSION"
  value         = var.build_version != null ? var.build_version : ""
}

resource "github_actions_variable" "var_framework" {
  count         = var.framework != null ? 1 : 0
  repository    = var.repository_name
  variable_name = "FRAMEWORK"
  value         = var.framework != null ? var.framework : ""
}

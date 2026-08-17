terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.68.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.13.0"
    }
  }
}

# Configure the GitHub Provider
provider "github" {
  owner = var.github_username
}

provider "azurerm" {
  # Configuration options
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  client_id       = var.arm_client_id
  client_secret   = var.arm_client_secret
  subscription_id = var.arm_subscription_id
  tenant_id       = var.arm_tenant_id
}

provider "azuread" {
  tenant_id     = var.arm_tenant_id
  client_id     = var.arm_client_id
  client_secret = var.arm_client_secret
}

data "azurerm_client_config" "current" {}

module "resource_group" {
  source = "./modules/azure-resource-group"

  project_name   = var.repo_name
  env_dash_abrev = var.env_abrev_dash
  rg_location    = var.rg_location

}

resource "azurerm_user_assigned_identity" "aca_identity" {
  name                = "id-${var.repo_name}${var.env_abrev_dash}"
  resource_group_name = module.resource_group.resource_group_name
  location            = module.resource_group.resource_group_location

  depends_on = [module.resource_group]
}

module "acr" {
  source = "./modules/azure-acr"

  project_name   = var.repo_name
  env_dash_abrev = var.env_abrev_dash
  resource_group = module.resource_group.resource_group_name
  location       = module.resource_group.resource_group_location

  depends_on = [module.resource_group]
}

resource "azurerm_role_assignment" "aca_acr_pull" {
  scope                = module.acr.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aca_identity.principal_id
}

resource "azurerm_role_assignment" "acr_push_github" {
  scope                = module.acr.acr_id
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.github_actions_sp.object_id

  depends_on = [module.acr]
}

module "azure-sql" {
  source = "./modules/azure-sql-database"

  project_name        = var.repo_name
  env_dash_abrev      = var.env_abrev_dash
  environment         = replace(var.env_abrev_dash, "-", "")
  resource_group_name = module.resource_group.resource_group_name
  location            = module.resource_group.resource_group_location

  sqbdb_users_max_size_gb = var.sqbdb_users_max_size_gb
  sqbdb_users_sku_name    = var.sqbdb_users_sku_name

  depends_on = [module.resource_group]
}

module "logs" {
  source = "./modules/azure-logs"

  project_name        = var.repo_name
  env_dash_abrev      = var.env_abrev_dash
  resource_group_name = module.resource_group.resource_group_name
  location            = module.resource_group.resource_group_location

  depends_on = [module.resource_group]
}

module "container_apps" {
  source = "./modules/azure-containers-apps"

  project_name                     = var.repo_name
  env_dash_abrev                   = var.env_abrev_dash
  location                         = module.resource_group.resource_group_location
  resource_group_name              = module.resource_group.resource_group_name
  log_analytics_workspace_id       = module.logs.log_analytics_workspace_id
  appinsights_connection_string    = module.logs.application_insights_connection_string
  appinsights_instrumentation_key  = module.logs.application_insights_instrumentation_key
  users_database_connection_string = module.azure-sql.portal_connection_string

  depends_on = [
    module.azure-sql,
    module.logs,
    azurerm_role_assignment.aca_acr_pull
  ]
}

module "repo" {
  source = "./modules/repo"

  name        = var.repo_name
  description = var.repo_description
  visibility  = var.repo_visibility
}

module "repo-env" {
  source = "./modules/repo-env"

  repository_name = module.repo.repository_name

  depends_on = [module.repo]
}

module "repo-labels" {
  source = "./modules/repo-labels"

  repository_name = module.repo.repository_name

  depends_on = [module.repo]
}

module "repo-secret" {
  source = "./modules/repo-secrets"

  repository_name = module.repo.repository_name

  sonar_token           = var.sonar_token
  sonar_project_key     = var.sonar_project_key
  azure_client_id       = azuread_application.github_actions_app.client_id
  azure_tenant_id       = data.azurerm_client_config.current.tenant_id
  azure_subscription_id = data.azurerm_client_config.current.subscription_id

  otlp_honeycomb_headers = var.otlp_honeycomb_headers

  depends_on = [module.repo]
}

module "repo-var" {
  source = "./modules/repo-var"

  repository_name            = module.repo.repository_name
  deploy_target              = var.deploy_target
  container_registry         = var.container_registry
  azure_acr_registry         = module.acr.acr_login_server
  azure_acr_pull_identity_id = azurerm_user_assigned_identity.aca_identity.id
  azure_resource_group_base = trimsuffix(
    module.resource_group.resource_group_name,
    var.env_abrev_dash
  )
  azure_acae_base    = "cae-${var.repo_name}"
  sonar_organization = var.sonar_organization
  sonar_project_name = var.sonar_project_name
  build_version      = var.build_version
  framework          = var.framework

  depends_on = [module.repo]
}

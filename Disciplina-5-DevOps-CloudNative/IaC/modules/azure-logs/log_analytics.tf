resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = "log-${var.project_name}${var.env_dash_abrev}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "app_insights" {
  name                = "appi-${var.project_name}${var.env_dash_abrev}"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.log_analytics.id
}

resource "azurerm_application_insights_api_key" "read_telemetry" {
  name                    = "tf-appinsights-read-telemetry-api-key"
  application_insights_id = azurerm_application_insights.app_insights.id
  read_permissions        = ["aggregate", "api", "draft", "extendqueries", "search"]
}

resource "azurerm_application_insights_api_key" "write_annotations" {
  name                    = "tf-appinsights-write-annotations-api-key"
  application_insights_id = azurerm_application_insights.app_insights.id
  write_permissions       = ["annotations"]
}

resource "azurerm_application_insights_api_key" "authenticate_sdk_control_channel" {
  name                    = "tf-appinsights-authenticate-sdk-control-channel-api-key"
  application_insights_id = azurerm_application_insights.app_insights.id
  read_permissions        = ["agentconfig"]
}

resource "azurerm_application_insights_api_key" "full_permissions" {
  name                    = "tf-appinsights-full-permissions-api-key"
  application_insights_id = azurerm_application_insights.app_insights.id
  read_permissions        = ["agentconfig", "aggregate", "api", "draft", "extendqueries", "search"]
  write_permissions       = ["annotations"]
}

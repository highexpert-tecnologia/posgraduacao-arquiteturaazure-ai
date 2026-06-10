# =============================================================================
# Mod07 - Lab de Observabilidade (jornada de mensagem) - versao Terraform
# Fluxo: APIM -> Function Producer -> Service Bus -> Function Consumer -> Blob + Cosmos
#        tudo correlacionado em um unico Application Insights.
#
# Infra SELF-CONTAINED: provisiona TUDO do zero. Autenticacao de dados via
# Managed Identity + RBAC (sem connection string p/ dados).
# =============================================================================

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
  numeric = true
}

locals {
  suffix = var.name_suffix != "" ? var.name_suffix : random_string.suffix.result

  la_name       = "log-${var.name_prefix}-${local.suffix}"
  ai_name       = "appi-${var.name_prefix}-${local.suffix}"
  sb_namespace  = "sb-${var.name_prefix}-${local.suffix}"
  storage_name  = substr(lower(replace("st${var.name_prefix}${local.suffix}", "-", "")), 0, 24)
  cosmos_name   = "cosmos-${var.name_prefix}-${local.suffix}"
  plan_name     = "plan-${var.name_prefix}-${local.suffix}"
  producer_name = "func-${var.name_prefix}-producer-${local.suffix}"
  consumer_name = "func-${var.name_prefix}-consumer-${local.suffix}"
  apim_name     = "apim-${var.name_prefix}-${local.suffix}"

  # Cosmos DB Built-in Data Contributor (data plane)
  cosmos_data_contributor_role_id = "00000000-0000-0000-0000-000000000002"
}

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# -----------------------------------------------------------------------------
# Observabilidade: Log Analytics + Application Insights (workspace-based)
# -----------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "law" {
  name                = local.la_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "appi" {
  name                = local.ai_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = "web"
  tags                = var.tags
}

# -----------------------------------------------------------------------------
# Service Bus: namespace + fila
# -----------------------------------------------------------------------------
resource "azurerm_servicebus_namespace" "sb" {
  name                = local.sb_namespace
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_servicebus_queue" "queue" {
  name         = var.queue_name
  namespace_id = azurerm_servicebus_namespace.sb.id

  max_delivery_count                   = 10
  lock_duration                        = "PT1M"
  dead_lettering_on_message_expiration = true
}

# -----------------------------------------------------------------------------
# Storage: conta + container 'messages'
# (tambem e o AzureWebJobsStorage do host das Functions, via connection string)
# -----------------------------------------------------------------------------
resource "azurerm_storage_account" "storage" {
  name                            = local.storage_name
  location                        = azurerm_resource_group.this.location
  resource_group_name             = azurerm_resource_group.this.name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = var.tags
}

resource "azurerm_storage_container" "messages" {
  name                  = var.blob_container_name
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

# -----------------------------------------------------------------------------
# Cosmos DB SQL serverless: account + database + container (PK /correlationId)
# -----------------------------------------------------------------------------
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = local.cosmos_name
  location            = var.cosmos_location
  resource_group_name = azurerm_resource_group.this.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  tags                = var.tags

  capabilities {
    name = "EnableServerless"
  }

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.cosmos_location
    failover_priority = 0
  }
}

resource "azurerm_cosmosdb_sql_database" "db" {
  name                = var.cosmos_database_name
  resource_group_name = azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
}

resource "azurerm_cosmosdb_sql_container" "container" {
  name                  = var.cosmos_container_name
  resource_group_name   = azurerm_resource_group.this.name
  account_name          = azurerm_cosmosdb_account.cosmos.name
  database_name         = azurerm_cosmosdb_sql_database.db.name
  partition_key_paths   = ["/correlationId"]
  partition_key_version = 2
}

# -----------------------------------------------------------------------------
# Plano de hospedagem (Consumption Y1, Linux) + 2 Function Apps (.NET 8 isolated)
# -----------------------------------------------------------------------------
resource "azurerm_service_plan" "plan" {
  name                = local.plan_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = var.tags
}

resource "azurerm_linux_function_app" "producer" {
  name                = local.producer_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  service_plan_id     = azurerm_service_plan.plan.id

  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key

  functions_extension_version = "~4"
  https_only                  = true
  tags                        = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    ftps_state             = "Disabled"
    minimum_tls_version    = "1.2"
    application_insights_connection_string = azurerm_application_insights.appi.connection_string

    application_stack {
      dotnet_version              = "8.0"
      use_dotnet_isolated_runtime = true
    }
  }

  app_settings = {
    "ServiceBusConnection__fullyQualifiedNamespace" = "${azurerm_servicebus_namespace.sb.name}.servicebus.windows.net"
    "QUEUE_NAME"                                     = var.queue_name
  }
}

resource "azurerm_linux_function_app" "consumer" {
  name                = local.consumer_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  service_plan_id     = azurerm_service_plan.plan.id

  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key

  functions_extension_version = "~4"
  https_only                  = true
  tags                        = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    ftps_state             = "Disabled"
    minimum_tls_version    = "1.2"
    application_insights_connection_string = azurerm_application_insights.appi.connection_string

    application_stack {
      dotnet_version              = "8.0"
      use_dotnet_isolated_runtime = true
    }
  }

  app_settings = {
    "ServiceBusConnection__fullyQualifiedNamespace" = "${azurerm_servicebus_namespace.sb.name}.servicebus.windows.net"
    "QUEUE_NAME"                                     = var.queue_name
    "STORAGE_BLOB_URI"                              = azurerm_storage_account.storage.primary_blob_endpoint
    "BLOB_CONTAINER"                                = var.blob_container_name
    "COSMOS_ENDPOINT"                               = azurerm_cosmosdb_account.cosmos.endpoint
    "COSMOS_DATABASE"                               = var.cosmos_database_name
    "COSMOS_CONTAINER"                              = var.cosmos_container_name
  }
}

# -----------------------------------------------------------------------------
# RBAC (data plane via Managed Identity)
# -----------------------------------------------------------------------------

# Producer -> Service Bus Data Sender (namespace)
resource "azurerm_role_assignment" "producer_sb_sender" {
  scope                = azurerm_servicebus_namespace.sb.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_linux_function_app.producer.identity[0].principal_id
}

# Consumer -> Service Bus Data Receiver (namespace)
resource "azurerm_role_assignment" "consumer_sb_receiver" {
  scope                = azurerm_servicebus_namespace.sb.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azurerm_linux_function_app.consumer.identity[0].principal_id
}

# Consumer -> Storage Blob Data Contributor (storage)
resource "azurerm_role_assignment" "consumer_blob" {
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.consumer.identity[0].principal_id
}

# Consumer -> Cosmos DB Built-in Data Contributor (data plane)
resource "azurerm_cosmosdb_sql_role_assignment" "consumer_cosmos" {
  resource_group_name = azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  role_definition_id  = "${azurerm_cosmosdb_account.cosmos.id}/sqlRoleDefinitions/${local.cosmos_data_contributor_role_id}"
  principal_id        = azurerm_linux_function_app.consumer.identity[0].principal_id
  scope               = azurerm_cosmosdb_account.cosmos.id
}

# -----------------------------------------------------------------------------
# APIM: servico + named value + API + operacao + policy + subscription
# -----------------------------------------------------------------------------
resource "azurerm_api_management" "apim" {
  name                = local.apim_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  publisher_email     = var.publisher_email
  publisher_name      = var.publisher_name
  sku_name            = var.apim_sku_name
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }
}

# Chave de funcao 'default' (host key) do Producer p/ o named value do APIM.
data "azurerm_function_app_host_keys" "producer" {
  name                = azurerm_linux_function_app.producer.name
  resource_group_name = azurerm_resource_group.this.name

  depends_on = [azurerm_linux_function_app.producer]
}

resource "azurerm_api_management_named_value" "producer_key" {
  name                = "func-mod07-producer-key"
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.this.name
  display_name        = "func-mod07-producer-key"
  secret              = true
  value               = data.azurerm_function_app_host_keys.producer.default_function_key
}

resource "azurerm_api_management_api" "api" {
  name                  = "mod07-producer"
  api_management_name   = azurerm_api_management.apim.name
  resource_group_name   = azurerm_resource_group.this.name
  revision              = "1"
  display_name          = "Mod07 Producer"
  path                  = "mod07"
  protocols             = ["https"]
  subscription_required = true
  service_url           = "https://${azurerm_linux_function_app.producer.default_hostname}/api"
}

resource "azurerm_api_management_api_operation" "send" {
  operation_id        = "send"
  api_name            = azurerm_api_management_api.api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.this.name
  display_name        = "Send"
  method              = "POST"
  url_template        = "/send"
}

resource "azurerm_api_management_api_policy" "policy" {
  api_name            = azurerm_api_management_api.api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.this.name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <set-header name="x-functions-key" exists-action="override">
      <value>{{func-mod07-producer-key}}</value>
    </set-header>
    <set-header name="x-apim-correlation-id" exists-action="skip">
      <value>@(context.RequestId.ToString())</value>
    </set-header>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML

  depends_on = [azurerm_api_management_named_value.producer_key]
}

resource "azurerm_api_management_subscription" "sub" {
  subscription_id     = "mod07-sub"
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.this.name
  api_id              = azurerm_api_management_api.api.id
  display_name        = "Mod07 Lab Subscription"
  state               = "active"
  allow_tracing       = true
}

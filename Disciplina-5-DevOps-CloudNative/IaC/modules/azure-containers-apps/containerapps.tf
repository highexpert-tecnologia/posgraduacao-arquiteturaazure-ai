resource "azurerm_container_app_environment" "aca_env" {
  name                       = "cae-${var.project_name}${var.env_dash_abrev}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = var.log_analytics_workspace_id
  logs_destination           = "log-analytics"

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

output "aca_environment_name" {
  description = "Name of the Container Apps environment."
  value       = azurerm_container_app_environment.aca_env.name
}

resource "azurerm_container_app" "container_app" {
  name                         = "ca-${var.project_name}${var.env_dash_abrev}"
  container_app_environment_id = azurerm_container_app_environment.aca_env.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  secret {
    name  = "appinsights-connection-string"
    value = var.appinsights_connection_string
  }

  secret {
    name  = "appinsights-instrumentation-key"
    value = var.appinsights_instrumentation_key
  }

  secret {
    name  = "users-database-connection-string"
    value = var.users_database_connection_string
  }

  template {
    min_replicas = 1
    max_replicas = 5

    container {
      name = "container-${var.project_name}${var.env_dash_abrev}"
      #image  = "mendhak/http-https-echo:41"
      image  = "docker.io/felipementel/pos-graduacao-high-expert:1.0"
      cpu    = 0.25
      memory = "0.5Gi"


      liveness_probe {
        transport        = "HTTP"
        port             = 8080
        path             = "/"
        initial_delay    = 10
        interval_seconds = 10
        timeout          = 5
      }

      readiness_probe {
        transport        = "HTTP"
        port             = 8080
        path             = "/"
        initial_delay    = 10
        interval_seconds = 10
        timeout          = 5
      }

      env {
        name        = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        secret_name = "appinsights-connection-string"
      }

      env {
        name        = "APPINSIGHTS_INSTRUMENTATIONKEY"
        secret_name = "appinsights-instrumentation-key"
      }

      env {
        name        = "ConnectionStrings__UsersDatabase"
        secret_name = "users-database-connection-string"
      }
    }
  }

  ingress {
    external_enabled           = true
    transport                  = "auto"
    target_port                = 8080
    allow_insecure_connections = true
    client_certificate_mode    = "ignore"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = {
    environment = replace(var.env_dash_abrev, "-", "")
  }

  lifecycle {
    ignore_changes = [identity, registry]
  }

  depends_on = [
    azurerm_container_app_environment.aca_env
  ]
}

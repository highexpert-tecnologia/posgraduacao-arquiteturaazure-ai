resource "azurerm_container_registry" "acr_pos_graduacao" {
  name                = replace("acr${var.project_name}${var.env_dash_abrev}", "-", "")
  resource_group_name = var.resource_group
  location            = var.location
  sku                 = "Standard"
  admin_enabled       = false
}

resource "azurerm_container_registry_task" "purge" {
  name                  = "PurgeOldImages"
  container_registry_id = azurerm_container_registry.acr_pos_graduacao.id

  platform {
    os = "Linux"
  }

  timer_trigger {
    name     = "daily_purge_schedule"
    schedule = "0 0 * * *"
    enabled  = true
  }

  encoded_step {
    context_path = "/dev/null"

    task_content = base64encode(<<-EOF
      version: v1.1.0
      steps:
        - cmd: acr purge --filter '.*:.*' --keep 10 --untagged
    EOF
    )
  }
}

output "acr_id" {
  value = azurerm_container_registry.acr_pos_graduacao.id
}

output "acr_login_server" {
  value = azurerm_container_registry.acr_pos_graduacao.login_server
}

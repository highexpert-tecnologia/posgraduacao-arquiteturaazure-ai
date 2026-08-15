# Generate random password for SQL Server
resource "random_password" "sqlserver_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ephemeral "vault_kv_secret_v2" "db_password" {
#   mount = "secret"
#   name  = "db_creds"
# }

resource "azurerm_mssql_server" "sql" {
  name                         = "sql-${var.project_name}${var.env_dash_abrev}"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = random_password.sqlserver_password.result
  minimum_tls_version          = "1.2"

  lifecycle {
    ignore_changes = [administrator_login_password]
  }
}

resource "azurerm_mssql_firewall_rule" "client_ip_rule" {
  for_each  = var.client_public_ips
  name      = "Allow-${each.key}"
  server_id = azurerm_mssql_server.sql.id

  start_ip_address = each.value
  end_ip_address   = each.value
}

resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_database" "sqbdb_users" {
  name                                = "sql-db-users"
  server_id                           = azurerm_mssql_server.sql.id
  collation                           = "SQL_Latin1_General_CP1_CI_AS"
  license_type                        = "LicenseIncluded"
  max_size_gb                         = var.sqbdb_users_max_size_gb
  sku_name                            = var.sqbdb_users_sku_name
  enclave_type                        = "VBS"
  storage_account_type                = "Local"
  transparent_data_encryption_enabled = true
  zone_redundant                      = false

  tags = {
    environment = var.environment
  }

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = false
  }
}

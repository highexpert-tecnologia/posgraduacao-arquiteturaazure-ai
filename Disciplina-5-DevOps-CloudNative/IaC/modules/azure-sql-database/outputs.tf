output "portal_connection_string" {
  description = "SQL Server connection string for the portal database."
  sensitive   = true
  value = format(
    "Server=tcp:%s,1433;Initial Catalog=%s;Persist Security Info=False;User ID=%s;Password=%s;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;",
    azurerm_mssql_server.sql.fully_qualified_domain_name,
    azurerm_mssql_database.sqbdb_users.name,
    azurerm_mssql_server.sql.administrator_login,
    random_password.sqlserver_password.result
  )
}

output "administrator_login" {
  description = "SQL Server administrator username."
  value       = azurerm_mssql_server.sql.administrator_login
}

output "administrator_password" {
  description = "SQL Server administrator password."
  value       = random_password.sqlserver_password.result
  sensitive   = true
}

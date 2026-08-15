output "sql_username" {
  description = "SQL Server administrator username."
  value       = module.azure-sql.administrator_login
}

output "sql_password" {
  description = "SQL Server administrator password."
  value       = module.azure-sql.administrator_password
  sensitive   = true
}

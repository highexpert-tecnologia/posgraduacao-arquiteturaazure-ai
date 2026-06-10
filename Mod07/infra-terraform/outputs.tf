output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "app_insights_name" {
  value = azurerm_application_insights.appi.name
}

output "service_bus_namespace" {
  value = azurerm_servicebus_namespace.sb.name
}

output "queue" {
  value = azurerm_servicebus_queue.queue.name
}

output "storage_account" {
  value = azurerm_storage_account.storage.name
}

output "cosmos_account" {
  value = azurerm_cosmosdb_account.cosmos.name
}

output "producer_function_app" {
  value = azurerm_linux_function_app.producer.name
}

output "consumer_function_app" {
  value = azurerm_linux_function_app.consumer.name
}

output "apim_name" {
  value = azurerm_api_management.apim.name
}

output "test_endpoint" {
  description = "Endpoint de teste (use o header Ocp-Apim-Subscription-Key)."
  value       = "${azurerm_api_management.apim.gateway_url}/mod07/send"
}

output "get_subscription_key_cmd" {
  description = "Comando para obter a chave da subscription do APIM."
  value       = "az apim subscription show -g ${azurerm_resource_group.this.name} --service-name ${azurerm_api_management.apim.name} --sid mod07-sub --query primaryKey -o tsv"
}

variable "resource_group_name" {
  type        = string
  description = "Nome do resource group (sera criado)."
  default     = "rg-mod07-lab"
}

variable "location" {
  type        = string
  description = "Regiao principal dos recursos."
  default     = "eastus"
}

variable "cosmos_location" {
  type        = string
  description = "Regiao do Cosmos DB. East US 2 por padrao (East US deu falta de capacidade no lab)."
  default     = "eastus2"
}

variable "name_prefix" {
  type        = string
  description = "Prefixo base para nomear recursos (minusculas/numeros, 3-10 chars)."
  default     = "mod07"

  validation {
    condition     = can(regex("^[a-z0-9]{3,10}$", var.name_prefix))
    error_message = "name_prefix deve ter 3-10 caracteres, apenas minusculas e numeros."
  }
}

variable "name_suffix" {
  type        = string
  description = "Sufixo fixo p/ nomes (deixe vazio p/ gerar aleatorio de 6 chars)."
  default     = ""
}

variable "publisher_email" {
  type        = string
  description = "Email do publisher do APIM."
  default     = "hsouza.eduardo@gmail.com"
}

variable "publisher_name" {
  type        = string
  description = "Nome do publisher do APIM."
  default     = "Mod07 Lab"
}

variable "apim_sku_name" {
  type        = string
  description = "SKU do APIM. Consumption_0 deploya em minutos (ideal lab). Ex.: Developer_1, Basic_1, Standard_1."
  default     = "Consumption_0"
}

variable "queue_name" {
  type        = string
  description = "Nome da fila do Service Bus."
  default     = "mod07-msgjourney"
}

variable "blob_container_name" {
  type        = string
  description = "Container de blobs onde o Consumer arquiva os envelopes."
  default     = "messages"
}

variable "cosmos_database_name" {
  type        = string
  description = "Nome do database Cosmos."
  default     = "mod07"
}

variable "cosmos_container_name" {
  type        = string
  description = "Nome do container Cosmos (PK /correlationId)."
  default     = "pedidos"
}

variable "tags" {
  type        = map(string)
  description = "Tags aplicadas a todos os recursos."
  default = {
    projeto  = "mod07-observabilidade"
    ambiente = "lab"
  }
}

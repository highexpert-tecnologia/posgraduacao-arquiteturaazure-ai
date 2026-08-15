variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string

  validation {
    condition = contains([
      "brazilsouth"
    ], var.location)
    error_message = "Location must be a valid Azure region."
  }
}

variable "resource_group_name" {
  description = "Resource Group Name"
  type        = string
}

variable "environment" {
  description = "The environment tag for resources."
  type        = string
}

variable "env_dash_abrev" {
  description = "The suffix with dash to be added to resource names based on the environment."
  type        = string
  default     = ""
}

# SQL Server
variable "client_public_ips" {
  description = "IP from client"
  type        = map(string)
  default     = {}
}

# SQL Database
variable "sqbdb_users_max_size_gb" {
  description = "The maximum size in GB for the SQL Database used for data user."
  type        = number
}

variable "sqbdb_users_sku_name" {
  description = "The SKU name for the SQL Database used for data user."
  type        = string
}

## Parameters

variable "env_dash_abrev" {
  description = "The environment for which the infrastructure is being provisioned (e.g., dev, staging, prod)."
  type        = string
}

variable "project_name" {
  description = "The name of the project, used for naming resources."
  type        = string
}

variable "resource_group" {
  description = "The resource group where the Azure Container Registry will be created."
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

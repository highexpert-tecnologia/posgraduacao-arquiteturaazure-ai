variable "location" {
  description = "Default location of Azure Resources"
  type        = string
}

variable "resource_group_name" {
  description = "Resource Group Name"
  type        = string
}

variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "env_dash_abrev" {
  description = "The suffix with dash to be added to resource names based on the environment."
  type        = string
  default     = ""
}

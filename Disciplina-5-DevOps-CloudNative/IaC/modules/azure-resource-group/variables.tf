## Parameters

variable "project_name" {
  description = "The name of the project, used for naming resources."
  type        = string
}

variable "env_dash_abrev" {
  description = "The suffix with dash to be added to resource names based on the environment."
  type        = string
  default     = ""
}


variable "rg_location" {
  description = "Value for Azure Resource Group"
  type        = string
  default     = ""
}

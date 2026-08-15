variable "repository_name" {
  description = "The name of the GitHub repository"
  type        = string
}

variable "sonar_token" {
  description = "The SonarCloud admin token for the repository"
  type        = string
}

variable "sonar_project_key" {
  description = "The SonarQube project key for the repository"
  type        = string
}

variable "azure_client_id" {
  description = "The Azure Client ID for the repository"
  type        = string
}

variable "azure_tenant_id" {
  description = "The Azure Tenant ID for the repository"
  type        = string
}

variable "azure_subscription_id" {
  description = "The Azure Subscription ID for the repository"
  type        = string
}

variable "otlp_honeycomb_headers" {
  description = "Honeycomb OTLP auth header value"
  type        = string
  sensitive   = true
  default     = null
}

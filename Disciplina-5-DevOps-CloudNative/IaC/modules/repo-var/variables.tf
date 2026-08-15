variable "repository_name" {
  description = "The name of the GitHub repository"
  type        = string
}

variable "deploy_target" {
  description = "Where to deploy?"
  type        = string
  default     = null

  validation {
    condition     = var.deploy_target == null ? true : contains(["ACA", "AKS", "App Service", "Azure Functions", "Static Web App"], var.deploy_target)
    error_message = "Deploy target must be one of: ACA, AKS, App Service, Azure Functions, Static Web App."
  }
}

variable "container_registry" {
  description = "The container registry domain (e.g., docker.io, ghcr.io, myacr.azurecr.io)"
  type        = string
  default     = null

  validation {
    condition     = var.container_registry == null ? true : can(regex("^(docker\\.io|ghcr\\.io|[a-z0-9][a-z0-9-]*\\.azurecr\\.io)$", var.container_registry))
    error_message = "Container registry must be docker.io, ghcr.io, or a valid *.azurecr.io registry name."
  }
}

variable "azure_acr_registry" {
  description = "The Azure Container Registry login server provisioned for the repository"
  type        = string
}

variable "azure_acr_pull_identity_id" {
  description = "Resource ID of the user-assigned managed identity used by Container Apps to pull from ACR"
  type        = string
}

variable "azure_resource_group_base" {
  description = "Base resource group name used by GitHub Actions Container Apps naming"
  type        = string
}

variable "azure_acae_base" {
  description = "Base Container Apps environment name used by GitHub Actions naming"
  type        = string
}

variable "sonar_organization" {
  description = "The SonarCloud organization key"
  type        = string
}

variable "sonar_project_name" {
  description = "The SonarCloud project display name"
  type        = string
}

variable "build_version" {
  description = "Runtime/SDK version used to build the project (e.g., 10 for .NET, 21 for Java, 3.13 for Python, 20 for Node)"
  type        = string
  default     = null
}

variable "framework" {
  description = "Programming language/runtime of the project (e.g., dotnet, java, python, node)"
  type        = string
  default     = null
}

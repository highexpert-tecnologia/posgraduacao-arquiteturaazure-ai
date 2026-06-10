terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Backend remoto (state no Azure Storage). Config parcial: os valores
  # (resource_group_name, storage_account_name, container_name, key) sao
  # passados via `-backend-config` no `terraform init` (ver azure-pipelines.yml).
  # Para rodar local sem backend remoto, use: terraform init -backend=false
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

provider "random" {}

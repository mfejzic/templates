terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.14.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = ""     // find this in the subscription overview
  tenant_id       = ""     // find this in the entra overview
  client_id       = ""     // find in entra -> manage -> app registrations -> all applications -> use terraform client ID
  client_secret   = "" // find in entra -> manage -> app registrations -> all applications -> terraform -> manage -> certificates & secrets -> client secrets
}

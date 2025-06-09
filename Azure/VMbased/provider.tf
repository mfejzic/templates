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

/* switch backend to terraform cloud */

# terraform { 
#   cloud { 
    
#     organization = "default-mf" 

#     workspaces { 
#       name = "vmbased" 
#     } 
#   } 
# }

// when switching back to local follow these steps
  # command line -> Remove-Item -Recurse -Force .terraform
    # this will remove the .terraform file created by tf cloud

  # download state file from tf cloud, and move it to this directory
    # save, then terraform init
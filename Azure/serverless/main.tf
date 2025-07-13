

##  missing securirty groups
## do you need route tables? ssh into a container and interact with the internet
## fix cosmos
## fix route 53
## add grafana prometheus
## fix diagnostics and log workspace

locals {
  
  # this is a list, use count
  public_subnets = [
      { name = "public_subnet_1" , address_prefixes = "10.0.1.0/24" , zone = "1"},
      { name = "public_subnet_2" , address_prefixes = "10.0.2.0/24" , zone = "2"}
    ]

    # not used
    private_subnets = [
      { name = "private_subnet_1" , address_prefixes = "10.0.3.0/24" , zone = "1"},
      { name = "private_subnet_2" , address_prefixes = "10.0.4.0/24" , zone = "2"}
    ] 

  # this is a map, use for each
    nat_gateways = {
      zone1 = {
        name              = "zone1"
        public_ip_name    = "zone1"
        subnet_index       = 0,
        zone              = "1"
      }
      zone2 = {
        name              = "zone2"
        public_ip_name    = "zone2"
        subnet_index       = 1,
        zone              = "2"
    }
  }
}

# uses existing resource group
data "azurerm_resource_group" "main" {
  name = "serverless-group"
}

# resource "azurerm_resource_group" "main" {
#   name = data.azurerm_resource_group.main.name
#   location = data.azurerm_resource_group.main.location
# }

# block creates new virtual network
resource "azurerm_virtual_network" "vnet" {
  name = "serverless"
  resource_group_name = data.azurerm_resource_group.main.name
  location = data.azurerm_resource_group.main.location
  address_space = var.vnet_cidr
}


#----------------------------------- all subnets ------------------------------------#

# 1 block for both public subnets because they serve the same role
resource "azurerm_subnet" "public" {
  count = length(local.public_subnets)                              # use this with a list, not a map

  name = local.public_subnets[count.index].name
  resource_group_name = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  
  address_prefixes = [
    local.public_subnets[count.index].address_prefixes
  ]
}

resource "azurerm_subnet" "private" {
  name                 = "private_subnet"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet.name

  address_prefixes     = ["10.0.14.0/23"]                            # Make sure this block spans IPs usable across AZs

  # delegation {
  #   name = "delegation"
  #   service_delegation {
  #     name = "Microsoft.App/environments"
  #     actions = [
  #       "Microsoft.Network/virtualNetworks/subnets/action"
  #     ]
  #   }
  # }
}


#-------------------------------- nat gateway & associations ------------------------------------#

# create nat gateway -> associate to subnet -> create public ip -> associate IP to nat gateway
# each block refers to a map
resource "azurerm_nat_gateway" "nat" {
  for_each            = local.nat_gateways
  name                = each.value.name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  sku_name            = "Standard"
  zones               = [each.value.zone]
}

resource "azurerm_public_ip" "nat" {
  for_each            = local.nat_gateways
  name                = each.value.public_ip_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [each.value.zone]
}

resource "azurerm_subnet_nat_gateway_association" "nat" {
  for_each       = local.nat_gateways
  subnet_id      = azurerm_subnet.public[each.value.subnet_index].id
  nat_gateway_id = azurerm_nat_gateway.nat[each.key].id
}

resource "azurerm_nat_gateway_public_ip_association" "nat" {
  for_each         = local.nat_gateways
  nat_gateway_id   = azurerm_nat_gateway.nat[each.key].id
  public_ip_address_id = azurerm_public_ip.nat[each.key].id
}


#-------------------------------- route tables ------------------------------------#

# route from private subnet
# resource "azurerm_route_table" "route" {
#   name                = "private-route"
#   location            = data.azurerm_resource_group.main.location
#   resource_group_name = data.azurerm_resource_group.main.name

#   route {
#     name                   = "nat-access"                             // Route to internet via NAT Gateway
#     address_prefix         = "0.0.0.0/0"
#     next_hop_type          = "Internet"                                    // virtual applicance routes traffic to an azure service - requires next_hop_in_ip_address 
#     //next_hop_in_ip_address = azurerm_public_ip.public_ip_nat_zone2.ip_address  //NAT Gateway for internet access - comment this out if using internet
#   }
# }

# resource "azurerm_subnet_route_table_association" "route" {
#   subnet_id      = azurerm_subnet.private.id
#   route_table_id = azurerm_route_table.route.id
# }

#-------------------------------- network security groups ------------------------------------#





#-------------------------------- key vault ------------------------------------#

data "azurerm_client_config" "current" {}                           // retrieves terraform, local-machine, and user identity, refer to it in the kv access policy

resource "azurerm_key_vault" "kv" {
  name                        = "kv-mf37"
  location                    = data.azurerm_resource_group.main.location
  resource_group_name         = data.azurerm_resource_group.main.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = true
  soft_delete_retention_days  = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Set", "Get", "List", "Delete", "Recover"                                           // recover bring back secrets that were soft deleted
    ]
  }
}

resource "azurerm_key_vault_secret" "cosmos_key" {
  name         = "cosmos-key"
  value        = azurerm_cosmosdb_account.account.primary_key
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_cosmosdb_account.account]
}


resource "azurerm_key_vault_access_policy" "container_app_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_container_app.app.identity[0].principal_id

  secret_permissions = ["Get", "List", "Recover"]                                                 // recover bring back secrets that were soft deleted
}


#-------------------------------- container environment ------------------------------------#

resource "azurerm_container_app_environment" "env" {
  name                       = "main-environment"
  location                   = data.azurerm_resource_group.main.location
  resource_group_name        = data.azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
  infrastructure_subnet_id   = azurerm_subnet.private.id

  depends_on = [ azurerm_subnet.private ]
}

resource "azurerm_container_app" "app" {
  name                         = "main"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = data.azurerm_resource_group.main.name
  revision_mode                = "Single"
  max_inactive_revisions = 1

  template {

    init_container {
      name = "initialize"
      image = "mf37registry.azurecr.io/flask-cosmos-app:latest"
      cpu = 0.25
      memory = "0.5Gi"
      command = ["python", "init_db.py"]

      env {
        name  = "COSMOS_ENDPOINT"
        value = azurerm_cosmosdb_account.account.endpoint
      }

      env {
        name  = "COSMOS_KEY"
        secret_name = "cosmos-key"
      }

      env {
        name  = "COSMOS_DB_NAME"
        value = "tfex-cosmos-sql-db"
      }

      env {
        name  = "COSMOS_CONTAINER_NAME"
        value = "messages"
      }
    }
    
    container {
      name   = "app1"
      image  = "mf37registry.azurecr.io/flask-cosmos-app:latest"
      cpu    = 0.25
      memory = "0.5Gi"
      
      env {
        name  = "COSMOS_ENDPOINT"
        value = azurerm_cosmosdb_account.account.endpoint
      }

      env {
        name  = "COSMOS_KEY"
        secret_name = "cosmos-key"
      }

      env {
        name  = "COSMOS_DB_NAME"
        value = "tfex-cosmos-sql-db"
      }

      env {
        name  = "COSMOS_CONTAINER_NAME"
        value = "messages"
      }
    }
  }

  secret {
    name  = "cosmos-key"
    key_vault_secret_id = azurerm_key_vault_secret.cosmos_key.id
    identity = "System"
  }

  ingress {
    external_enabled = true
    target_port = 80
    
    traffic_weight {                                                               // you can specify revisions here and direct them percentage of the traffic
     percentage =  100
     latest_revision = true
    }
  }

  // container app has its own azure managed identity and needs AcrPull permission to pull image from ACR
  identity {
    type = "SystemAssigned"                          // works in conjuction with role assignment block below /// can use system assigned or user assigned
  }

  registry {
    server = azurerm_container_registry.acr.login_server
    username = azurerm_container_registry.acr.admin_username
    password_secret_name = azurerm_container_registry.acr.name
  }

  secret {
    name = azurerm_container_registry.acr.name
    value = azurerm_container_registry.acr.admin_password
  }

  depends_on = [ azurerm_container_registry.acr, null_resource.docker_push ]
}

# resource "azurerm_role_assignment" "container_acr_pull" {
#   principal_id         = azurerm_container_app.app.identity[0].principal_id            // refers to identity type above
#   role_definition_name = "AcrPull"
#   scope                = azurerm_container_registry.acr.id

#   depends_on = [ azurerm_container_app.app ]                                     // container_app must be created before the role
# }



#-------------------------------- container registry ------------------------------------#

resource "azurerm_container_registry" "acr" {
  name                = "mf37registry"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true

  # identity {
  #   type = "SystemAssigned"
  # }
  
  # georeplications {
  #   location                = "West US"
  #   zone_redundancy_enabled = true
  #   tags                    = {}
  # }
}

data "azurerm_container_registry" "acr" {                                         // retrieves metadeta like login_server, admin username and password
  name                = azurerm_container_registry.acr.name
  resource_group_name = data.azurerm_resource_group.main.name
}

// this will push the image into acr before creating the container app - container app will pull image from acr after
resource "null_resource" "docker_push" {                                          //refers to ps1 script to push image
  provisioner "local-exec" {
    command = "powershell.exe -ExecutionPolicy Bypass -File ./docker-push.ps1"
  }

  depends_on = [azurerm_container_registry.acr]
}


#-------------------------------- cosmos ------------------------------------#

// block creates account
resource "azurerm_cosmosdb_account" "account" {
  name                = "mf37"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  automatic_failover_enabled = true
  free_tier_enabled = true

  capabilities {
    name = "EnableServerless"                                       // Serverless model, great for scaling down costs
  }

  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 300
    max_staleness_prefix    = 100000
  }

  geo_location {
    location          = data.azurerm_resource_group.main.location
    failover_priority = 0
  }

  # geo_location {
  #   location = "eastus2"                                             // failover region
  #   failover_priority = 1
  # }
}

// block created database under cosmos account
resource "azurerm_cosmosdb_sql_database" "database" {
  name                = "tfex-cosmos-sql-db"
  resource_group_name = data.azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.account.name
  #throughput          = 400                                                       // only used for provisioned mode, comment when using serverless
}

//block creates container inside database
resource "azurerm_cosmosdb_sql_container" "container" {
  name                  = "messages"
  resource_group_name   = data.azurerm_resource_group.main.name
  account_name          = azurerm_cosmosdb_account.account.name
  database_name         = azurerm_cosmosdb_sql_database.database.name
  partition_key_paths   = ["/id"]
  partition_key_version = 2

  indexing_policy {
    indexing_mode = "consistent"                                                    // default
  }
}



#-------------------------------- log analytics ------------------------------------#

resource "azurerm_log_analytics_workspace" "logs" {
  name                = "main-workspace"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

#     ----- diagnostics -----     #
resource "azurerm_monitor_diagnostic_setting" "nat_diag" {
  name               = "nat-logs"
  target_resource_id = azurerm_nat_gateway.nat.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id


  metric {
    category = "AllMetrics"
    enabled  = true
  }
}


#-------------------------------- route 53 ------------------------------------#


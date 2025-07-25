

##  missing securirty groups
## fix private subnet and add internet outbound
## fix route 53
## add grafana prometheus
## fix diagnostics and log workspace

### remove cosmos key from key vault, have key valt for one microservice ###
### remove trigger fromm all operations and see if it works - it wokred before you applied trigger ###      it worked, now find
### setup firewall subnet and rotue table to route container traffic trhoguh the firewall ###
### setup promethues and grafana homie ### about time
# Run docker run -p 80:80 mf37registry.azurecr.io/trigger-app:latest locally to test the image
# From the main container, use curl -X POST http://trigger-app/trigger to test the endpoint

## add microservices
    # login
    # emotional tone AI
    # chat rooms
    # notification

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

  address_prefixes     = ["10.0.14.0/27"]                            # Make sure this block spans IPs usable across AZs

  delegation {
    name = "delegation"
    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }
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
resource "azurerm_route_table" "route" {
  name                = "private-route"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  route {
    name                   = "nat-access"                             // Route to internet via NAT Gateway
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "Internet"                                    // virtual applicance routes traffic to an azure service - requires next_hop_in_ip_address 
    //next_hop_in_ip_address = azurerm_public_ip.public_ip_nat_zone2.ip_address  //NAT Gateway for internet access - comment this out if using internet
  }
}

resource "azurerm_subnet_route_table_association" "route" {
  subnet_id      = azurerm_subnet.private.id
  route_table_id = azurerm_route_table.route.id
}

#-------------------------------- network security groups ------------------------------------#






#-------------------------------- cognitive AI ------------------------------------#

resource "azurerm_cognitive_account" "text_analytics" {
  name                = "cogsvc-mf37"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  kind                = "TextAnalytics"
  sku_name            = "F0"  # Use "S" tier for production

  identity {
    type = "SystemAssigned"
  }
}

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
      "Set", "Get", "List", "Delete", "Recover"                                           // recover bring back secrets that were soft deleted - or maunally purge the key vault
    ]
  }
}

#   ---   cosmos and twilio auth keys right here   ---   #
resource "azurerm_key_vault_secret" "cosmos_key" {         
  name         = "cosmos-key"
  value        = azurerm_cosmosdb_account.account.primary_key                              // refer to this is main container_app
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_cosmosdb_account.account]
}

# twilio
resource "azurerm_key_vault_secret" "twilio" {
  name         = "twilio-auth"
  value        = var.twilio_auth_token
  key_vault_id = azurerm_key_vault.kv.id
}

#   -------   access policies   -------   #

#   ---   check if this is needed   ---   #
resource "azurerm_key_vault_access_policy" "container_app_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_container_app.main.identity[0].principal_id

  secret_permissions = ["Get", "List", "Recover"]                                                 // recover bring back secrets that were soft 
  
  depends_on = [azurerm_container_app.main]
}


# Access Policy for User 1
resource "azurerm_key_vault_access_policy" "user1" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = "16983dae-9f48-4a35-b9f5-0519bf3cdf09"
  object_id    = "900a20af-26d8-47b0-85d0-b1437c8af627"  # User 1 object ID       // if not try

  key_permissions = [
    "Get", "List", "Create", "Update", "Import"
  ]

  secret_permissions = [
    "Get", "List", "Set", "Recover", "Delete", "Restore"
  ]

  certificate_permissions = [
    "Get", "List", "Create"
  ]

  depends_on = [azurerm_key_vault.kv]
}

# Access Policy for Local Machine 
resource "azurerm_key_vault_access_policy" "local_machine" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = "16983dae-9f48-4a35-b9f5-0519bf3cdf09"
  object_id    = "3728e04a-d9d3-4d3c-b503-b287b1aaa666"  # Local Machine object ID

  key_permissions = [
    "Get", "List", "Create", "Update", "Import"
  ]

  secret_permissions = [
    "Get", "List", "Set", "Recover", "Delete", "Restore"
  ]

  certificate_permissions = [
    "Get", "List", "Create"
  ]

  depends_on = [azurerm_key_vault.kv]
}

# Access Policy for Terraform Service Principal
resource "azurerm_key_vault_access_policy" "terraform_application" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = "16983dae-9f48-4a35-b9f5-0519bf3cdf09"
  object_id    = "a4815ff2-fc06-4608-b1c6-9b902ac9ffb3"  # Terraform Service Principal object ID

  key_permissions = [
    "Get", "List", "Create", "Update", "Import"
  ]

  secret_permissions = [
    "Get", "List", "Set", "Recover", "Delete", "Restore"
  ]

  certificate_permissions = [
    "Get", "List", "Create"
  ]

  depends_on = [azurerm_key_vault.kv]
}



#-------------------------------- container environment ------------------------------------#

resource "azurerm_container_app_environment" "env" {
  name                       = "main-environment"
  location                   = data.azurerm_resource_group.main.location
  resource_group_name        = data.azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  zone_redundancy_enabled = false
  infrastructure_subnet_id   = azurerm_subnet.private.id

// supports private IP comms between container apps
  workload_profile {                                                                                // needs 'environment' delegation and a subnet /27 - 
    name = "D4"                                                                                     // if you switch to consumption mode, remove delegation and change to /23cidr - no charge when idle - azure handles allocation and scaling
    workload_profile_type = "D4"
    maximum_count = 3
    minimum_count = 1
  }

  depends_on = [ azurerm_subnet.private ]
}

#              -- message board container --              #

# this microservice will initiliaze connection with database and run the message board
resource "azurerm_container_app" "main" {
  name                         = "main"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = data.azurerm_resource_group.main.name
  workload_profile_name = "D4"

  revision_mode                = "Single"
  max_inactive_revisions = 1

    ingress {
    external_enabled = true
    target_port = 80
    
    traffic_weight {                                                               // you can specify revisions here and direct them percentage of the traffic
     percentage =  100
     latest_revision = true
    }
  }

  template {

    init_container {                                                      // startup container will wait for cosmos, setup schema then exit. will never serve requests
      name = "initialize"
      image = "mf37registry.azurecr.io/main-app:latest"
      cpu = 0.25
      memory = "0.5Gi"
      command = ["python", "init_db.py"]                                  // this will initialize the schema

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
    
    container {                                                                   // single container instance will bootup after init_container exits
      name   = "app1"
      image  = "mf37registry.azurecr.io/main-app:latest"
      cpu    = 0.25
      memory = "0.5Gi"
      
      # next 4 envs refer cosmos                                                          // writes to db
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

      # this will call the script in sentiment folder
      env {
        name  = "SENTIMENT_API_URL"                                                                             // refers to main app.py
        value = "http://sentiment-app/analyze"                                                                  // keep this at default - external_enabled must be false -
        //value = "https://${azurerm_container_app.sentiment.latest_revision_fqdn}/analyze"                     // sentiment container external_enabled must be true for this value to work
      }

      # calls script in trigger folder
      env {
        name = "TRIGGER_API_URL"
        //value = "http://trigger-app/trigger"
        value = "https://${azurerm_container_app.trigger.latest_revision_fqdn}/trigger"                        // trigger container external_enabled must be true for this value to work  -- keep this commented out, use only for tshooting
      }
    }
  }

  secret {
    name  = "cosmos-key"
    key_vault_secret_id = azurerm_key_vault_secret.cosmos_key.id
    identity = "System"
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

  depends_on = [ 
    azurerm_container_registry.acr, 
    null_resource.push_main, 
    azurerm_container_app.sentiment 
  ]
}

#              -- sentiment container --              #

# this AI microservice will determine the mood of the message 
resource "azurerm_container_app" "sentiment" {
  name                         = "sentiment-app"
  resource_group_name          = data.azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.env.id
  revision_mode                = "Single"
  workload_profile_name = "D4"

    ingress {
    external_enabled = false                                                               // keep false - this will not have public access - needs delegated subnet to communicate privately with main container_app
    target_port      = 80
    allow_insecure_connections = true

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      name   = "sentiment"
      image  = "mf37registry.azurecr.io/sentiment-app:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "COG_ENDPOINT"
        value = azurerm_cognitive_account.text_analytics.endpoint
      }

      env {
        name        = "COG_KEY"                                            // the env ar inside the container
        secret_name = "cog-key"                                            // refers to the 'secret' block below
      }
    }

    min_replicas = 1
    max_replicas = 4
  }

  secret {
    name  = "cog-key"                                                     // matches 'secret_name' above
    value = azurerm_cognitive_account.text_analytics.primary_access_key
  }

  identity {
    type = "SystemAssigned"
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

  depends_on = [ azurerm_container_registry.acr, null_resource.push_cog ]
}

#              -- trigger container --              #

# this microservice will send message to my number anytime the board gets a new chat
resource "azurerm_container_app" "trigger" {
  name                         = "trigger-app"
  resource_group_name          = data.azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.env.id
  revision_mode                = "Single"
  workload_profile_name = "D4"

    ingress {
    external_enabled = true                                                               // keep false - this will not have public access - needs delegated subnet to communicate privately with main container_app
    target_port      = 80
    allow_insecure_connections = true

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      name   = "trigger"
      image  = "mf37registry.azurecr.io/trigger-app:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name = "TWILIO_SID"
        value = "nunya"
      }

      env {
        name = "TWILIO_FROM"
        value = "+18776748048"
      }

      env {
        name = "TWILIO_TO"
        value = "+17733661263"
      }

      env {
        name = "TWILIO_AUTH"
        secret_name = "twilio-auth"
      }
    }

    min_replicas = 1
    max_replicas = 4
  }

  secret {
    name = "twilio-auth"
    key_vault_secret_id = azurerm_key_vault_secret.twilio.id
    identity = "System"
  }

  identity {
    type = "SystemAssigned"
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

  depends_on = [ azurerm_container_registry.acr, null_resource.push_trigger ]
}



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
#     - push main app -     #
resource "null_resource" "push_main" {                                          //refers to ps1 script to push image
  provisioner "local-exec" {
    command = "powershell.exe -ExecutionPolicy Bypass -File ./docker-push.ps1"
  }

  depends_on = [azurerm_container_registry.acr]
}

#     - push cog -     #
resource "null_resource" "push_cog" {                                          //refers to ps1 script to push image
  provisioner "local-exec" {
    command = "powershell.exe -ExecutionPolicy Bypass -File ./sentiment/docker-push.ps1"
  }

  depends_on = [azurerm_container_registry.acr]
}

#     - push trigger -     #
resource "null_resource" "push_trigger" {                                          //refers to ps1 script to push image
  provisioner "local-exec" {
    command = "powershell.exe -ExecutionPolicy Bypass -File ./trigger/docker-push.ps1"
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

resource "azurerm_log_analytics_workspace" "law" {
  name                = "main-workspace"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

//comment out diagnotiscs till you fix

# -------  diagnostics  ------- #

# # message board metrics
# resource "azurerm_monitor_diagnostic_setting" "main" {
#   name               = "message-board-logs"
#   target_resource_id = azurerm_container_app.main.id
#   log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

#   # enabled_log {
#   #   category = "AppLogs"
#   # }
#   # enabled_log {
#   #   category = "SystemLogs"
#   # }

#   metric {
#     category = "AllMetrics"
#     enabled  = true
#   }
# }

# # sentiment metrics
# resource "azurerm_monitor_diagnostic_setting" "sentiment" {
#   name                       = "sentiment-logs"
#   target_resource_id         = azurerm_container_app.sentiment.id
#   log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

#   metric {
#     category = "AllMetrics"
#     enabled  = true
#   }
# }

# # trigger metrics
# resource "azurerm_monitor_diagnostic_setting" "trigger" {
#   name                       = "trigger-logs"
#   target_resource_id         = azurerm_container_app.trigger.id
#   log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

#   metric {
#     category = "AllMetrics"
#     enabled  = true
#   }
# }

# #cosmos metrics
# resource "azurerm_monitor_diagnostic_setting" "cosmos" {
#   name                       = "cosmos-logs"
#   target_resource_id         = azurerm_cosmosdb_account.account.id
#   log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

#   enabled_log {
#     category = "DataPlaneRequests"
#   }

#   # enabled_log {
#   #   category = "QueryRunStatistics"
#   # }

#   metric {
#     category = "AllMetrics"
#     enabled  = true
#   }
# }


#-------------------------------- route 53 ------------------------------------#

# data "aws_route53_zone" "hosted_zone" {
#   name = "fejzic37.com"                                                          
# }

# # Primary A Record 
# resource "aws_route53_record" "primary_cname" {
#   zone_id = data.aws_route53_zone.hosted_zone.id
#   name    = "www.${data.aws_route53_zone.hosted_zone.name}"
#   type    = "A"
#   ttl     = 10
#   health_check_id = aws_route53_health_check.primary_health_check.id

#   records = [azurerm_public_ip.app_gateway.ip_address]                                    

#   set_identifier = "primary"                                                 // will failover to US east if regional failure
#   failover_routing_policy {
#     type = "PRIMARY"
#   }
# }

# # check primary endpoint
# resource "aws_route53_health_check" "primary_health_check" {
#   fqdn = "www.${data.aws_route53_zone.hosted_zone.name}"
#   type = "HTTPS"
#   //resource_path = "/index.html"
#   port = 443
# }

# //Secondary A Record
# resource "aws_route53_record" "secondary_cname" {
#   zone_id = data.aws_route53_zone.hosted_zone.zone_id
#   name    = "www.${data.aws_route53_zone.hosted_zone.name}"
#   type    = "A"
#   ttl     = 10
#   records = [azurerm_public_ip.app_gateway.ip_address]                         

#   set_identifier = "secondary"
#   failover_routing_policy {
#     type = "SECONDARY"
#   }
# }

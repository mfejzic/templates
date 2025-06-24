locals {
  storage_log_categories = [
    "StorageRead",
    "StorageDelete",
    "StorageWrite"
  ]
  cdn_log_categories = [
    "AzureCdnAccessLog",
  ]
  jpg_files = [
    "cfbuild.jpg",
    "cloudfront.jpg",
    "cloudnetOF.jpg",
    "ec2build.jpg",
    "eks.jpg",
    "farbuild.jpg",
    "kubuild.jpg",
    "mfejziccloudresume.jpg",
    "serverless.jpg",
    "toigif.gif"
  ]
}

data "azurerm_resource_group" "main_RG" {
  name = "main"
}

// change diagnostics to storage accounts
// check the lgos see if metrics are working
// dones
# ------------------------------------- US West -------------------------------------#

#refer storage account if needed
data "azurerm_storage_account" "westus" {
  name                = azurerm_storage_account.SA_west.name
  resource_group_name = data.azurerm_resource_group.main_RG.name
}

#create primary storage account
resource "azurerm_storage_account" "SA_west" {
  name                     = "mf37west"
  resource_group_name      = data.azurerm_resource_group.main_RG.name
  location                 = var.uswest
  account_tier             = "Standard"
  account_replication_type = "RAGRS"

  tags = {
    environment = var.dev
  }
}

#enable static website and upload html files
resource "azurerm_storage_account_static_website" "SA_west_static_website" {
  storage_account_id = azurerm_storage_account.SA_west.id
  error_404_document = var.error
  index_document     = var.index

  depends_on = [azurerm_storage_account.SA_west]
}

# resource "azurerm_storage_container" "west_container" {                               // if default $web is created first, manually delete it, then re-run apply  - or delete container block and manually upload index file into defualt $web container and switch access to blob
#   name                  = "$web"
#   storage_account_name = azurerm_storage_account.SA_west.name
#   container_access_type = "blob"
# }

#use this block refer to container $web 
data "azurerm_storage_container" "web_container_west" {
  name                  = var.default_container                                              // manually switch access type to blob - its private by default
  storage_account_name  = azurerm_storage_account.SA_west.name
  

  depends_on = [ azurerm_storage_account_static_website.SA_west_static_website ]  // depends on enabling static website
}

#create blob to source index file
resource "azurerm_storage_blob" "west_blob" {
  name                   = var.index
  storage_account_name   = azurerm_storage_account.SA_west.name
  storage_container_name = data.azurerm_storage_container.web_container_west.name      // $web is created by default after enabling static website, its recommended to upload index.html in this container
  type                   = "Block"
  source                 = var.index
  content_type = "text/html"                                                        // make sure content type is text/html for all blobs
}

#create blob to source 404 error
resource "azurerm_storage_blob" "west_error_blob" {
  name                   = var.error
  storage_account_name   = azurerm_storage_account.SA_west.name
  storage_container_name = data.azurerm_storage_container.web_container_west.name
  type                   = "Block"
  source                 = var.error
  content_type = "text/html"
}

# Use a for_each to create a blob for each JPG file
resource "azurerm_storage_blob" "jpg_blobs_west" {
  for_each              = toset(local.jpg_files)
  name                  = each.value
  storage_account_name  = azurerm_storage_account.SA_west.name
  storage_container_name = data.azurerm_storage_container.web_container_west.name
  type                  = "Block"
  source                = "jpg/${each.value}"  //Local path to the JPG file

  content_type = each.value != null && (
    substr(each.value, length(each.value) - 3, 3) == "jpg" || 
    substr(each.value, length(each.value) - 3, 3) == "JPG" ) ? "image/jpeg" : (substr(each.value, length(each.value) - 3, 3) == "gif" ||    //logic sets content type to image/jpeg or image/gif based on the file's extension
    substr(each.value, length(each.value) - 3, 3) == "GIF" ) ? "image/gif" : "application/octet-stream"

}

resource "azurerm_storage_account_network_rules" "west_logs" {                    // allow all incoming traffic, with exceptions for Azure Metrics to bypass the network rules
  storage_account_id = azurerm_storage_account.SA_west.id

  default_action             = "Allow"
  ip_rules                   = ["0.0.0.0/0"]
  bypass                     = ["Metrics"]
}


# ------------------------------------- US East 2 -------------------------------------#


resource "azurerm_storage_account" "SA_east" {
  name                     = "mf37east"
  resource_group_name      = data.azurerm_resource_group.main_RG.name
  location                 = var.useast2
  account_tier             = "Standard"
  account_replication_type = "RAGRS"

  tags = {
    environment = var.dev
  }
}

resource "azurerm_storage_account_static_website" "SA_east_static_website" {
  storage_account_id = azurerm_storage_account.SA_east.id
  error_404_document = var.error
  index_document     = var.index

  depends_on = [azurerm_storage_account.SA_east]
}

# resource "azurerm_storage_container" "east_container" {                               // if default $web is created first, manually delete it, then re-run apply  - or delete container block and manually upload index file into defualt $web container and switch access to blob
#   name                  = "$web"
#   storage_account_name = azurerm_storage_account.SA_east.name
#   container_access_type = "blob"
# }

# Data block to reference the $web container created by Azure
data "azurerm_storage_container" "web_container_east" {
  name                  = var.default_container
  storage_account_name  = azurerm_storage_account.SA_east.name
  

  depends_on = [ azurerm_storage_account_static_website.SA_east_static_website ]
}

resource "azurerm_storage_blob" "east_blob" {
  name                   = var.index
  storage_account_name   = azurerm_storage_account.SA_east.name
  storage_container_name = data.azurerm_storage_container.web_container_east.name                                       // $web is created by default after enabling static website, upload index.html in this container
  type                   = "Block"
  source                 = var.index
  content_type = "text/html"
}

resource "azurerm_storage_blob" "east_error_blob" {
  name                   = var.error
  storage_account_name   = azurerm_storage_account.SA_east.name
  storage_container_name = data.azurerm_storage_container.web_container_east.name 
  type                   = "Block"
  source                 = var.error
  content_type = "text/html"
}

resource "azurerm_storage_blob" "jpg_blobs_east" {
  for_each              = toset(local.jpg_files)
  name                  = each.value
  storage_account_name  = azurerm_storage_account.SA_east.name
  storage_container_name = data.azurerm_storage_container.web_container_east.name
  type                  = "Block"
  source                = "jpg/${each.value}"  # Local path to the JPG file

  content_type = each.value != null && (
    substr(each.value, length(each.value) - 3, 3) == "jpg" || 
    substr(each.value, length(each.value) - 3, 3) == "JPG" ) ? "image/jpeg" : (substr(each.value, length(each.value) - 3, 3) == "gif" || 
    substr(each.value, length(each.value) - 3, 3) == "GIF" ) ? "image/gif" : "application/octet-stream"

}

resource "azurerm_storage_account_network_rules" "east_logs" {
  storage_account_id = azurerm_storage_account.SA_east.id

  default_action             = "Allow"
  ip_rules                   = ["0.0.0.0/0"]
  bypass                     = ["Metrics"]
}


# ------------------------------------- Log Analytics -------------------------------------#

# Create the Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main_workspace" {
  name                = "main-log-analytics-workspace"
  location            = data.azurerm_resource_group.main_RG.location
  resource_group_name = data.azurerm_resource_group.main_RG.name
  sku                 = "PerGB2018"

  retention_in_days = 30

  tags = {
    environment = var.dev
  }

  depends_on = [ azurerm_cdn_profile.cdn_profile ]
}

# Enable diagnostic settings for Storage Account in US West
resource "azurerm_monitor_diagnostic_setting" "west_diagnostic" {
  name               = "west-diagnostics"
  target_resource_id = azurerm_storage_account.SA_west.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main_workspace.id

  metric {
    category = "AllMetrics"
  }

  depends_on = [ azurerm_log_analytics_workspace.main_workspace, azurerm_cdn_endpoint.primary_endpoint ]
}

# Enable diagnostic settings for Storage Account in US East
resource "azurerm_monitor_diagnostic_setting" "east_diagnostic" {
  name               = "east-diagnostics"
  target_resource_id = azurerm_storage_account.SA_east.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main_workspace.id

  metric {
    category = "AllMetrics"
  }

  depends_on = [ azurerm_log_analytics_workspace.main_workspace, azurerm_cdn_endpoint.secondary_endpoint]
}

# enable diagnostics for the CDN
resource "azurerm_monitor_diagnostic_setting" "cdn" {                            //sends cache, traffics, performance metrics to log analytics workspace
  name               = "cdn_diagnostics"
  target_resource_id = azurerm_cdn_profile.cdn_profile.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main_workspace.id
  storage_account_id = azurerm_storage_account.SA_east.id                       // archives results in east storage account, incase of regional failure - workspace located in us west

  dynamic "enabled_log" {                                                  // references values from locals block
    for_each = toset(local.cdn_log_categories)                      // add additional log entries to locals block
    content {
      category = enabled_log.value
    }
  }

  metric {
    category = "AllMetrics"
  }
}


# ------------------------------------- CDN profile & endpoints -------------------------------------#

# Generate a random ID to append to the endpoint name
resource "random_id" "random_id" {
  byte_length = 8
}

# Create Azure CDN profile
resource "azurerm_cdn_profile" "cdn_profile" {
  name                = "cdn-profile"
  resource_group_name = data.azurerm_resource_group.main_RG.name
  location            = "Global"
  sku = "Standard_Microsoft"

  tags = {
    environment = var.dev
  }
}

# Primary CDN Endpoint in US West (points to primary storage)
resource "azurerm_cdn_endpoint" "primary_endpoint" {
  name               = "primary-endpoint-${random_id.random_id.hex}"                  // endpoint names are globally unique
  profile_name       = azurerm_cdn_profile.cdn_profile.name
  resource_group_name = data.azurerm_resource_group.main_RG.name
  location = data.azurerm_resource_group.main_RG.location
  optimization_type = "GeneralWebDelivery"
  is_https_allowed = true
  origin_host_header = azurerm_storage_account.SA_west.primary_web_host                          // this was causing all the problems - make sure its added in all cdn endpoints
  
  
  origin {
    name      = "primary"
    host_name = azurerm_storage_account.SA_west.primary_web_host                                  //host_name = replace(replace(azurerm_storage_account.SA_west.primary_web_endpoint, "https://", ""), "/", "")    // use replace regex to remove the https:// and last slash from the host name - went from "https://mf37west.z22.web.core.windows.net/\ to mf37west.z22.web.core.windows.net/
    http_port = 80
    https_port = 443
  }

  depends_on = [ azurerm_cdn_profile.cdn_profile, azurerm_storage_account.SA_west ]
}

# Secondary CDN Endpoint in US East (points to secondary storage)
resource "azurerm_cdn_endpoint" "secondary_endpoint" {
  name               = "secondary-endpoint-${random_id.random_id.hex}"
  profile_name       = azurerm_cdn_profile.cdn_profile.name
  resource_group_name = data.azurerm_resource_group.main_RG.name
  location = var.useast2
  optimization_type = "GeneralWebDelivery"
  origin_host_header = azurerm_storage_account.SA_east.secondary_web_host

  origin {
    name      = "secondary"
    host_name = replace(replace(azurerm_storage_account.SA_east.secondary_web_endpoint, "https://", ""), "/", "") // enable GRS or RA_GRS in storage account to use the secondary web endpoint as a backup!!! if stil facing issues with secondary, use primary until GRS propogates across regions
    //host_name = azurerm_storage_account.SA_east.secondary_web_host                                             // use this if top one doesnt work
  }

  depends_on = [ azurerm_cdn_profile.cdn_profile, azurerm_storage_account.SA_east, azurerm_cdn_endpoint.primary_endpoint /* add primary endpoint */]
}

resource "azurerm_cdn_endpoint_custom_domain" "primary_endpoint_custom_domain" {
  name            = "domain"
  cdn_endpoint_id = azurerm_cdn_endpoint.primary_endpoint.id
  host_name       = "www.fejzic37.com"
#   cdn_managed_https {
#     certificate_type = "Shared"
#     protocol_type = "IPBased"                                              // manually enable custom https on azure portal - no idea why im getting cert type not supported error
#   }

   depends_on = [ azurerm_cdn_endpoint.primary_endpoint, aws_route53_record.primary_cname ]
}

# ------------------------------------- Route53 -------------------------------------#

data "aws_route53_zone" "hosted_zone" {
  name = "fejzic37.com"                                                          // your actual domain name managed in Route 53
}

# Primary CNAME Record (points to the Azure CDN endpoint for primary)
resource "aws_route53_record" "primary_cname" {
  zone_id = data.aws_route53_zone.hosted_zone.id
  name    = "www.${data.aws_route53_zone.hosted_zone.name}"
  type    = "CNAME"
  ttl     = 10
  health_check_id = aws_route53_health_check.primary_health_check.id

  records = [azurerm_cdn_endpoint.primary_endpoint.fqdn]                      // should be the cdn endpoint if using cname, not your subdomain - must point to cdn endpoint                     

  set_identifier = "primary"                                                 // will failover to US east in event of regional failure
  failover_routing_policy {
    type = "PRIMARY"
  }

  depends_on = [ azurerm_cdn_profile.cdn_profile ]
}

# check primary endpoint
resource "aws_route53_health_check" "primary_health_check" {
  fqdn = "www.${data.aws_route53_zone.hosted_zone.name}"
  type = "HTTPS"
  //resource_path = "/index.html"
  port = 443
  
}

//Secondary CNAME Record (points to the Azure CDN endpoint for secondary with failover)
resource "aws_route53_record" "secondary_cname" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = "www.${data.aws_route53_zone.hosted_zone.name}"
  type    = "CNAME"
  ttl     = 10
  records = [azurerm_cdn_endpoint.secondary_endpoint.fqdn]                         // points to secondary cdn endpoint

  set_identifier = "secondary"
  failover_routing_policy {
    type = "SECONDARY"
  }

   depends_on = [ aws_route53_record.primary_cname, azurerm_cdn_endpoint_custom_domain.primary_endpoint_custom_domain ]   // should be dependent on primary endpoint custom domain
}


# ------------------------------------- Cloudwatch & SNS topic -------------------------------------#


# create an sns topic 
resource "aws_sns_topic" "route53_alarm_topic" {
  name = "alarm_topic"
}

resource "aws_sns_topic_subscription" "route53_sns" {            // email notification incase of unhealthy endpoint - disconnection
  topic_arn = aws_sns_topic.route53_alarm_topic.arn
  protocol  = "email"
  endpoint  = "muhazic3@gmail.com"  
}

#create cloudwatch alarm to monitor the dns health check
resource "aws_cloudwatch_metric_alarm" "route53_health_check_alarm" {
  alarm_name                = "Route53HealthCheckFailure"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = 1
  metric_name               = "HealthCheckStatus"
  namespace                 = "AWS/Route53"
  period                    = 60
  statistic                 = "Minimum"
  threshold                 = 1                            //Threshold for healthy check is 1, so this will alarm if status is 0 (unhealthy)
  alarm_description         = "Alarm when Route 53 health check fails"
  actions_enabled           = true
  alarm_actions             = [aws_sns_topic.route53_alarm_topic.arn]
  insufficient_data_actions = []
  ok_actions               = [aws_sns_topic.route53_alarm_topic.arn]

  dimensions = {
    HealthCheckId = aws_route53_health_check.primary_health_check.id  
  }
}

# output "dns_zone_name" {
#   value = data.azurerm_dns_zone.dns_zone.name
#   description = "The name of the DNS zone"
# }

# output "resource_group_name" {
#   value = data.azurerm_resource_group.main_RG.name
#   description = "The name of the resource group"
# }

output "secondary_web_endpoint" {
  value = azurerm_storage_account.SA_east.secondary_web_endpoint
}
output "primary_endpoint_fqdn" {
  value = azurerm_cdn_endpoint.primary_endpoint.fqdn  
}

output "cdn_primary_endpoint_origin" {
  value = azurerm_cdn_endpoint.primary_endpoint.origin
}

output "primary_web_host" {
  value = azurerm_storage_account.SA_west.primary_web_host
}
output "primary_blob_host" {
  value = azurerm_storage_account.SA_west.primary_blob_host
}
output "primary_web_endpoint" {
  value = azurerm_storage_account.SA_west.primary_web_endpoint
}
output "primary_blob_endpoint" {
  value = azurerm_storage_account.SA_west.primary_blob_endpoint
}
output "primary_file_host" {
  value = azurerm_storage_account.SA_west.primary_file_host
}
output "primary_endpoint_custom_domain_name" {
  value = azurerm_cdn_endpoint_custom_domain.primary_endpoint_custom_domain.name
}
output "primary_endpoint_custom_domain_host_name" {
  value = azurerm_cdn_endpoint_custom_domain.primary_endpoint_custom_domain.host_name
}
output "azurerm_cdn_endpoint_primary_endpoint_fqdn" {
  value = azurerm_cdn_endpoint.primary_endpoint.fqdn
}


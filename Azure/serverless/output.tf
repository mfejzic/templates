output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "acr_admin_username" {
  value = azurerm_container_registry.acr.admin_username
}

output "acr_admin_password" {
  value = azurerm_container_registry.acr.admin_password
  sensitive = true
}

output "cog_name" {
  value = azurerm_cognitive_account.text_analytics.name
}
output "cog_endpoint" {
  value = azurerm_cognitive_account.text_analytics.endpoint
}
output "cog_key" {
  value = azurerm_cognitive_account.text_analytics.primary_access_key
  sensitive = true
}

output "sentiment_revision_url" {
  value = azurerm_container_app.sentiment.latest_revision_fqdn
}


output "container_app_identity" {
  value = azurerm_container_app.main.identity[0].principal_id
}

output "cosmos_key_secret_id" {
  value = azurerm_key_vault_secret.cosmos_key.id
}

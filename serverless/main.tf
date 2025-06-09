data "azurerm_resource_group" "main" {
  name = "vmbased-vnet"
}

resource "azurerm_resource_group" "main" {
  name = data.azurerm_resource_group.main.name
  location = data.azurerm_resource_group.main.location
}
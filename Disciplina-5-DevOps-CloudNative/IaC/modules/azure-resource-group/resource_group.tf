resource "azurerm_resource_group" "rg_pos_graduacao" {
  name     = "rg-${var.project_name}${var.env_dash_abrev}"
  location = var.rg_location
}

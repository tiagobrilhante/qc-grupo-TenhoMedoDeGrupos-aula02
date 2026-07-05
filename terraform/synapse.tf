# Exercício 3.2 — Synapse Serverless para query sobre Blob (zero ETL).

resource "azurerm_synapse_workspace" "qc" {
  name                                 = "synapse-qc-${random_string.sufixo.result}"
  resource_group_name                  = azurerm_resource_group.rg.name
  location                             = azurerm_resource_group.rg.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.synapse.id
  sql_administrator_login              = "synadmin"
  sql_administrator_login_password     = var.sql_admin_password
  identity { type = "SystemAssigned" }
  tags = local.tags
}

# Synapse precisa de Data Lake Storage Gen2
resource "azurerm_storage_data_lake_gen2_filesystem" "synapse" {
  name               = "synapsefs"
  storage_account_id = azurerm_storage_account.qc.id # precisa de is_hns_enabled=true
}

resource "azurerm_synapse_firewall_rule" "all_azure" {
  name                 = "AllowAzure"
  synapse_workspace_id = azurerm_synapse_workspace.qc.id
  start_ip_address     = "0.0.0.0"
  end_ip_address       = "0.0.0.0"
}
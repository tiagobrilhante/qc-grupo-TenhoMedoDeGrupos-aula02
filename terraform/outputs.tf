# Saídas usadas pelos scripts do N3 (exportar como variáveis de ambiente).

output "resource_group_name" {
  description = "Nome do Resource Group da QC"
  value       = azurerm_resource_group.rg.name
}

output "storage_account_name" {
  description = "STORAGE_ACCOUNT_NAME — usado por vector_search.py e no upload dos CSVs"
  value       = azurerm_storage_account.qc.name
}

output "search_endpoint" {
  description = "SEARCH_ENDPOINT — usado por vector_search.py"
  value       = "https://${azurerm_search_service.qc.name}.search.windows.net"
}

output "synapse_workspace_name" {
  description = "Nome do Synapse workspace (abrir no Synapse Studio p/ o Ex. 3.2)"
  value       = azurerm_synapse_workspace.qc.name
}

# Base do N3 — subconjunto do lab da disciplina, só com o que o N3 usa:
#   https://github.com/elthonf/aie-cloud/tree/main/aulas/02-storage-bancos/lab
# Provisiona resource group, storage (HNS) + containers, AI Search (search.tf) e
# Synapse (synapse.tf, nossa adição). Cosmos/SQL/Key Vault/Mongo do lab não entram
# aqui porque o N3 não depende deles. Nomes e tags alinhados ao lab.

terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    # azapi: habilita o semantic ranker do AI Search no SKU free, que o
    # provider azurerm 3.x não permite configurar (ver search.tf).
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.15"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

# Objeto do usuário autenticado — usado para conceder RBAC no AI Search (search.tf).
data "azurerm_client_config" "current" {}

resource "random_string" "sufixo" {
  length  = 6
  upper   = false
  special = false
}

locals {
  tags = {
    aula         = "2"
    disciplina   = "cloud-cognitive"
    projeto      = "quantum-commerce"
    provisionado = "terraform"
  }
}

# Resource Group da Aula 2 (mesmo naming do lab)
resource "azurerm_resource_group" "rg" {
  name     = "rg-qc-aula02-${random_string.sufixo.result}"
  location = var.location
  tags     = local.tags
}

# Storage Account — igual ao lab, PORÉM com is_hns_enabled=true, requisito do
# Data Lake Gen2 / Synapse (nossa alteração do Ex. 3.2).
resource "azurerm_storage_account" "qc" {
  name                     = "stqc${random_string.sufixo.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  is_hns_enabled           = true
  tags                     = local.tags
}

# Container do catálogo (destino do data/produtos.csv; origem do vector_search.py — Ex. 3.1)
resource "azurerm_storage_container" "catalogo" {
  name                  = "catalogo"
  storage_account_name  = azurerm_storage_account.qc.name
  container_access_type = "private"
}

# Container de logs (destino dos CSVs do gerar_logs.py; origem do OPENROWSET no Synapse — Ex. 3.2)
resource "azurerm_storage_container" "logs" {
  name                  = "logs"
  storage_account_name  = azurerm_storage_account.qc.name
  container_access_type = "private"
}

# Acesso data-plane ao Blob para a identidade do Cloud Shell: sem esta role, o
# `az storage blob upload --auth-mode login` e o DefaultAzureCredential dos
# scripts recebem 403 ao ler/escrever blobs.
resource "azurerm_role_assignment" "blob_data" {
  scope                = azurerm_storage_account.qc.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
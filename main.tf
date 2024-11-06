# terraform init
# terraform plan
# terraform apply
# terraform fmt

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.8.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
  subscription_id = "556b3479-49e0-4048-ace9-9b100efe5b6d"
  # Configuration options
}

resource "azurerm_resource_group" "rg" {
  name     = "raphaeld"
  location = "West Europe"
}

# #CREER UN STORAGE ACCOUNT DANS VOTRE RESOURCE GROUP EN TERRAFORM
# #FAIRE EN SORTE QUE L ACCESS TIER SOIT EN "COOL" ET PAS EN "HOT"

resource "azurerm_storage_account" "storage" {
  name                     = "raphstoragerand"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  access_tier              = "Cool" 
}

#DEPLOYER UN STORAGE CONTAINER DANS VOTRE STORAGE ACCOUNT EN TERRAFORM

resource "azurerm_storage_container" "container" {
  name                  = "mycontainer"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

#DEPLOYER UN KEYVAULT TERRAFORM, BIEN AJOUTEZ DANS LE BLOC FEATURES DU PROVIDER

resource "azurerm_key_vault" "keyvault" {
  name                        = "raphkeyvault"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get",
    ]

    storage_permissions = [
      "Get",
    ]
  }
}

#CREER UN SECRET DANS VOTRE KEYVAULT
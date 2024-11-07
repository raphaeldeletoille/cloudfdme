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
      purge_soft_deleted_secrets_on_destroy = true
      recover_soft_deleted_secrets          = true
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
      "Set",
      "Get",
      "Delete",
      "Purge",
      "Recover",
      "List"
    ]

    storage_permissions = [
      "Get",
    ]
  }
}

#CREER UN SECRET DANS VOTRE KEYVAULT. RAJOUTEZ DANS LE BLOC FEATURE LA DOC SECRET

resource "azurerm_key_vault_secret" "mdpsql" {
  name         = "mdpsql"
  value        = random_password.password.result
  key_vault_id = azurerm_key_vault.keyvault.id
}

#REMPLACEZ LA VALEUR DE VOTRE MDP PAR UN MDP GENERE ALEATOIREMENT
resource "random_password" "password" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_numeric      = 2
  min_special      = 1
  keepers = {
    rotation = time_rotating.twomonths.id
  }
}

#AUTO CHANGE PASSWORD TOUS LES DEUX MOIS
resource "time_rotating" "twomonths" {
  rotation_months = 2
}

#DEPLOYER UN MSSQL SERVER & UN MSSQL DATABASE 
#SKU DE LA MSSQL DATABASE = "GP_S_Gen5_2"
#VOUS ALLEZ ATTRIBUER VOTRE MDP SECURISE AU SQL SERVER
#VOTRE DATABASE DOIT POUVOIR ETRE DETRUITE
#CONNECTEZ VOUS A VOTRE DATABASE "QUERY" DEPUIS LE PORTAIL AZURE PUIS CREER UNE TABLE
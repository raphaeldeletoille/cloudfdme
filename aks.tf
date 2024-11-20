terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.8.0"
    }
  }
}

provider "azurerm" {
  # Configuration options
  features {
  }
}

data "azurerm_user_assigned_identity" "acridentity" {
  name                = "acridentity"
  resource_group_name = "identities"
}


resource "azurerm_resource_group" "example" {
  name     = "test"
  location = "West Europe"
}

resource "azurerm_kubernetes_cluster" "example" {
  name                = "test-aks1"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  dns_prefix          = "exampleaks1"
  sku_tier            = "Standard" 

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type                      = "UserAssigned"
    identity_ids              = [data.azurerm_user_assigned_identity.acridentity.id]
  }

  kubelet_identity {
    user_assigned_identity_id = data.azurerm_user_assigned_identity.acridentity.id
    client_id                 = data.azurerm_user_assigned_identity.acridentity.client_id
    object_id                 = data.azurerm_user_assigned_identity.acridentity.principal_id
  }

  tags = {
    Environment = "Production"
  }
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.example.kube_config[0].client_certificate
  sensitive = true
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.example.kube_config_raw

  sensitive = true
}

resource "azurerm_container_registry" "example" {
  name                = "raphfdmeregistry"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "Premium"
}
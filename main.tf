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
  }
  subscription_id = "556b3479-49e0-4048-ace9-9b100efe5b6d"
  # Configuration options
}

resource "azurerm_resource_group" "rg" {
  name     = "raphaeld"
  location = "West Europe"
}

#CREER UN STORAGE ACCOUNT DANS VOTRE RESOURCE GROUP EN TERRAFORM
#FAIRE EN SORTE QUE L ACCESS TIER SOIT EN "COOL" ET PAS EN "HOT"

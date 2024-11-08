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
      purge_soft_delete_on_destroy          = true
      recover_soft_deleted_key_vaults       = true
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
#LA LOCATION DE VOTRE MSSQL SERVER ET DATABASE DOIT ETRE WEST US

resource "azurerm_mssql_server" "sqlsrv" {
  name                         = "raph-sqlserver-west"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = "West US"
  version                      = "12.0"
  administrator_login          = "raph"
  administrator_login_password = random_password.password.result
}

resource "azurerm_mssql_database" "sqldb" {
  name                        = "raph-db"
  server_id                   = azurerm_mssql_server.sqlsrv.id
  max_size_gb                 = 2
  min_capacity                = 1
  auto_pause_delay_in_minutes = 60
  sku_name                    = "GP_S_Gen5_2"
}

#DEPLOYER 1 VIRTUAL NETWORK (VNET)
#DEPLOYER 3 SUBNET (SOUS RESEAU) DANS CE VNET. Utiliser 1 seul bloc avec count pour faire ca

resource "azurerm_virtual_network" "vnet" {
  name                = "raph-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  count                = 3
  name                 = "raph-subnet${count.index}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.${count.index}.0/24"]
}

#DEPLOYER 3 RESOURCE GROUP A PARTIR D UN SEUL BLOC, LES LOCATIONS ET LES TAGS SOIENT DIFFERENT
#UTILISEZ DES VARIABLES 
#1e RG = "West Europe", Tag Number "1". 
#2eme RG = "West US", Tag Number = "2"
#3eme RG = "Japan", Tag Number = "3"

resource "azurerm_resource_group" "all_rg" {
  for_each = var.all_rg
  name = "raph-${each.key}"
  location = each.value.location 
  tags = each.value.tags
}

#DEPLOYER 1 VM LINUX OU WINDOWS SERVER DANS VOTRE 1ER SOUS RESEAU
#SIZE DE VOTRE VM = "Standard_B2ms"

resource "azurerm_network_interface" "networkcard" {
  name                = "raph-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet[0].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.IP.id
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "raph-machine"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2ms"
  admin_username      = "adminuser"
  admin_password      = random_password.password.result 
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.networkcard.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

#ASSIGNER UNE IP PUBLIC A VOTRE VM
#VOUS CONNECTER A VOTRE VM
#ASSIGNEZ DEUX DISQUES DE 1TO A VOTRE VM

resource "azurerm_public_ip" "IP" {
  name                = "raphIP"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_security_group" "vmnsg" {
  name                = "raphVMs"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "raphVM"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "connect" {
  network_interface_id      = azurerm_network_interface.networkcard.id
  network_security_group_id = azurerm_network_security_group.vmnsg.id
}

resource "azurerm_managed_disk" "disk" {
  count                = 2
  name                 = "disk${count.index}"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1024"
}

resource "azurerm_virtual_machine_data_disk_attachment" "diskattach" {
  count              = 2
  managed_disk_id    = azurerm_managed_disk.disk[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.vm.id
  lun                = count.index
  caching            = "ReadWrite"
}

#ENVOYER TOUS LES LOGS ET METRICS DE VOTRE KEYVAULT ET DE VOTRE STORAGE ACCOUNT
#SUR MON LOG ANALYTICS
resource "azurerm_log_analytics_workspace" "log" {
  name                = "raph-log"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}



resource "azurerm_monitor_diagnostic_setting" "kvlog" {
  name               = "send-log-to-raph"
  target_resource_id = azurerm_key_vault.keyvault.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log.id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "storagelog" {
  name               = "send-log-to-raph"
  target_resource_id = azurerm_storage_account.storage.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log.id

  metric {
    category = "AllMetrics"
  }
}

#DEPLOYER UN GRAFANA MANAGE, VOUS ALLEZ VOUS CONNECTER A CE GRAPHANA

resource "azurerm_dashboard_grafana" "grafana" {
  name                              = "raph-grafana"
  resource_group_name               = azurerm_resource_group.rg.name
  location                          = "West Europe"
  grafana_major_version             = 10
  api_key_enabled                   = true
  deterministic_outbound_ip_enabled = true
  public_network_access_enabled     = true

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "monitoringReader" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.grafana.identity[0].principal_id
}

resource "azurerm_role_assignment" "Raph" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Grafana Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}

#DEPLOYER UNE ALERTE AZURE QUI VA UTILISER VOTRE ADRESSE MAIL ET VOUS PREVENIR LORSQUE VOTRE
#KEYVAULT A UN LOG FORBIDDEN
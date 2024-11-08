data "azurerm_client_config" "current" {}

# data "azurerm_log_analytics_workspace" "LOGANALYTICSPROF" {
#   name                = "raph-log"
#   resource_group_name = "raphaeld"
# }

# output "log_analytics_workspace_id" {
#   value = data.azurerm_log_analytics_workspace.LOGANALYTICSPROF.workspace_id
# }
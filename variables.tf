variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "tenant_id" {
  type        = string
  description = "Azure Entra tenant ID"
}

variable "location" {
  type        = string
  description = "Resource location (e.g. eastus2)"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name"
}

# ===============================
# Networking
# ===============================
variable "vnet_name" {
  type        = string
  description = "Virtual network name"
}

variable "address_space" {
  type        = list(string)
  description = "Address space for the VNet (e.g. [\"10.0.0.0/16\"])"
}

variable "subnet_ag_cidr" {
  type        = string
  description = "Address range for Application Gateway subnet (e.g. 10.0.1.0/24)"
}

variable "subnet_integration_cidr" {
  type        = string
  description = "Address range for Integration subnet (e.g. 10.0.2.0/24)"
}

variable "subnet_privateendpoint_cidr" {
  type        = string
  description = "Address range for Private Endpoint subnet (e.g. 10.0.3.0/24)"
}

# ===============================
# App Service
# ===============================
variable "app_service_plan_name" {
  type        = string
  description = "App Service Plan name"
}

variable "webapp_name" {
  type        = string
  description = "App Service (Windows Web App) name"
}

# ===============================
# SQL Server
# ===============================
variable "sql_server_name" {
  type        = string
  description = "SQL Server name"
}

variable "sql_admin_login" {
  type        = string
  description = "SQL Server admin login"
}

variable "sql_admin_password" {
  type        = string
  description = "SQL Server admin password"
  sensitive   = true
}

variable "sql_database_name" {
  type        = string
  description = "SQL Database name"
}

# ===============================
# Key Vault
# ===============================
variable "key_vault_name" {
  type        = string
  description = "Azure Key Vault name"
}

# ===============================
# Application Gateway
# ===============================
variable "appgateway_name" {
  type        = string
  description = "Application Gateway name"
  default     = "appgateway-cheriza"
}

variable "appgateway_publicip_name" {
  type        = string
  description = "Application Gateway Public IP name"
  default     = "agw-public-ip"
}
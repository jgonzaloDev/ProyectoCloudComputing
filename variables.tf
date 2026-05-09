# ==========================================
# Variables de Azure - Autenticación
# ==========================================
variable "client_id" {
  description = "Azure Client ID"
  type        = string
}

variable "client_secret" {
  description = "Azure Client Secret"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

# ==========================================
# Variables de Recursos
# ==========================================
variable "resource_group_name" {
  description = "Nombre del grupo de recursos"
  type        = string
  default     = "AmorRescate"
}

variable "location" {
  description = "Región de Azure"
  type        = string
  default     = "East US 2"
}

variable "app_service_name" {
  description = "Nombre del App Service"
  type        = string
  default     = "amorRescate"
}

# ==========================================
# Variables de SQL Server
# ==========================================
variable "sql_server_name" {
  description = "Nombre del servidor SQL"
  type        = string
  default     = "admindojo"
}

variable "sql_database_name" {
  description = "Nombre de la base de datos"
  type        = string
  default     = "albergue"
}

variable "sql_admin_user" {
  description = "Usuario administrador de SQL"
  type        = string
  default     = "dojo"
}

variable "sql_admin_password" {
  description = "Contraseña del administrador de SQL"
  type        = string
  sensitive   = true
}

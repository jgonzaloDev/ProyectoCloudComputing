# ============================================================
# VARIABLES GLOBALES PARA EL DESPLIEGUE EN AZURE
# ============================================================

# ID de la suscripción de Azure
variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

# ID del tenant (directorio) de Azure
variable "tenant_id" {
  type        = string
  description = "Azure tenant ID"
}

# Región donde se desplegarán los servicios (por ejemplo: eastus2)
variable "location" {
  type        = string
  description = "Azure region for deployment"
}

# ============================================================
# VARIABLES DE IDENTIDAD Y GRUPO DE RECURSOS
# ============================================================

# Identidad de la aplicación (GitHub Actions OIDC)
variable "terraform_principal_id" {
  type        = string
  description = "Object ID of the Service Principal or GitHub OIDC identity"
}

# Grupo de recursos existente
variable "resource_group_name" {
  type        = string
  description = "Nombre del grupo de recursos existente en Azure"
}

# ============================================================
# VARIABLES DE RED Y PLAN DE SERVICIO
# ============================================================

# Nombre de la red virtual existente
variable "vnet_name" {
  type        = string
  description = "Nombre de la red virtual donde se despliegan los servicios"
  default     = null
}

# Nombre del plan de App Service existente
variable "app_service_plan_name" {
  type        = string
  description = "Nombre del App Service Plan existente"
}

# Nombre del App Service (backend)
variable "app_service_name" {
  type        = string
  description = "Nombre del App Service (backend Laravel o API)"
}

# ============================================================
# VARIABLES DE KEY VAULT
# ============================================================

# Nombre del Key Vault existente
variable "key_vault_name" {
  type        = string
  description = "Nombre del Key Vault existente"
}

# ============================================================
# VARIABLES DE BASE DE DATOS (SQL SERVER)
# ============================================================

# Nombre del servidor SQL
variable "sql_server_name" {
  type        = string
  description = "Nombre del servidor SQL existente"
}

# Nombre de la base de datos
variable "database_name" {
  type        = string
  description = "Nombre de la base de datos existente"
}

# Usuario administrador del servidor SQL
variable "sql_admin_login" {
  type        = string
  description = "Usuario administrador del servidor SQL"
  default     = null
}

# Contraseña del administrador SQL
variable "sql_admin_password" {
  type        = string
  description = "Contraseña del administrador del servidor SQL"
  default     = null
}

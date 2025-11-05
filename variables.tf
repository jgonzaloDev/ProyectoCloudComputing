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

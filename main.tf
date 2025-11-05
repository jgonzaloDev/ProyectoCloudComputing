terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.34.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

# ============================================================
# 0. SUFIJO ALEATORIO PARA EVITAR CONFLICTOS DE NOMBRES
# ============================================================
resource "random_id" "suffix" {
  byte_length = 2
}

# ============================================================
# 1. GRUPO DE RECURSOS
# ============================================================
resource "azurerm_resource_group" "rg" {
  name     = "PRUEBAS_DEMO"
  location = "eastus2"
}

# ============================================================
# 2. SERVIDOR SQL
# ============================================================
resource "azurerm_mssql_server" "sql_server" {
  name                         = "pruebasql${random_id.suffix.hex}"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  version                       = "12.0"
  administrator_login           = "prueba1"
  administrator_login_password   = "123456789Da."
  minimum_tls_version           = "1.2"
}

resource "azurerm_mssql_database" "db" {
  name      = "BD_PRUEBA"
  server_id = azurerm_mssql_server.sql_server.id
  sku_name  = "Basic"
}

# ============================================================
# 3. APP SERVICE PLAN Y APP SERVICE
# ============================================================
resource "azurerm_service_plan" "plan" {
  name                = "plan-demo94"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "app" {
  name                = "apidemo${random_id.suffix.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true
  }

  app_settings = {
    WEBSITE_RUN_FROM_PACKAGE = "0"
  }
}

# ============================================================
# 4. KEY VAULT + RBAC (LECTURA/ESCRITURA)
# ============================================================
resource "azurerm_key_vault" "kv" {
  name                        = "keyprueba${random_id.suffix.hex}"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = var.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = false
  soft_delete_retention_days  = 7
  enable_rbac_authorization   = true
}

# Permisos RBAC al App Service
resource "azurerm_role_assignment" "keyvault_reader" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

resource "azurerm_role_assignment" "keyvault_writer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

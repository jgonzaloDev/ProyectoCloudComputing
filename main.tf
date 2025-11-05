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
# 0. SUFIJO ALEATORIO PARA NOMBRES ÚNICOS
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
# 2. SERVIDOR SQL Y BASE DE DATOS
# ============================================================
resource "azurerm_mssql_server" "sql_server" {
  name                         = "pruebasql${random_id.suffix.hex}"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  version                       = "12.0"
  administrator_login           = "prueba1"
  administrator_login_password  = "123456789Da."
  minimum_tls_version           = "1.2"
}

resource "azurerm_mssql_database" "db" {
  name      = "BD_PRUEBA"
  server_id = azurerm_mssql_server.sql_server.id
  sku_name  = "Basic"
}

# ============================================================
# 3. KEY VAULT (DEBE CREARSE ANTES DEL APP SERVICE)
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

# ============================================================
# 4. CREACIÓN AUTOMÁTICA DE SECRETOS DE LARAVEL
# ============================================================
resource "azurerm_key_vault_secret" "app_key" {
  name         = "app-key"
  value        = "base64:123456789ABCDEF123456789ABCDEF123456789ABCDEF123456789ABCDEF"
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "db_host" {
  name         = "db-host"
  value        = azurerm_mssql_server.sql_server.fully_qualified_domain_name
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "db_name" {
  name         = "db-name"
  value        = azurerm_mssql_database.db.name
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "db_user" {
  name         = "db-user"
  value        = azurerm_mssql_server.sql_server.administrator_login
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "db_pass" {
  name         = "db-pass"
  value        = azurerm_mssql_server.sql_server.administrator_login_password
  key_vault_id = azurerm_key_vault.kv.id
}

# ============================================================
# 5. APP SERVICE PLAN Y APP SERVICE (PHP 8.2)
# ============================================================
resource "azurerm_service_plan" "plan" {
  name                = "plan-demo${random_id.suffix.hex}"
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

  # --- Identidad administrada ---
  identity {
    type = "SystemAssigned"
  }

  # --- Configuración PHP 8.2 (nueva sintaxis compatible con azurerm >= 4.x) ---
  site_config {
    always_on = true
    application_stack {
      php_version = "8.2"
    }
  }

  # --- Variables de entorno Laravel ---
  app_settings = {
    WEBSITE_RUN_FROM_PACKAGE = "0"

    # Configuración general de Laravel
    APP_ENV   = "production"
    APP_DEBUG = "false"
    APP_KEY   = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.app_key.id})"

    # Configuración de base de datos
    DB_CONNECTION = "mysql"
    DB_HOST       = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.db_host.id})"
    DB_PORT       = "3306"
    DB_DATABASE   = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.db_name.id})"
    DB_USERNAME   = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.db_user.id})"
    DB_PASSWORD   = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.db_pass.id})"
  }

  depends_on = [
    azurerm_key_vault.kv,
    azurerm_key_vault_secret.app_key,
    azurerm_key_vault_secret.db_host,
    azurerm_key_vault_secret.db_name,
    azurerm_key_vault_secret.db_user,
    azurerm_key_vault_secret.db_pass
  ]
}

# ============================================================
# 6. ROLES RBAC DEL APP SERVICE EN EL KEY VAULT
# ============================================================

# Permite CREAR / ACTUALIZAR / ELIMINAR secretos
resource "azurerm_role_assignment" "keyvault_writer" {
  depends_on = [
    azurerm_linux_web_app.app,
    azurerm_key_vault.kv
  ]
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

# Permite LEER secretos (necesario para ejecución)
resource "azurerm_role_assignment" "keyvault_reader" {
  depends_on = [
    azurerm_linux_web_app.app,
    azurerm_key_vault.kv
  ]
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

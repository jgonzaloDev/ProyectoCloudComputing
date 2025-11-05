# ============================================================
# 1. ROLES RBAC
# ============================================================

# Rol ADMIN para la identidad de Terraform (GitHub OIDC o SPN)
resource "azurerm_role_assignment" "terraform_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.terraform_principal_id
}

# Rol para CREAR / ACTUALIZAR / ELIMINAR secretos (App Service)
resource "azurerm_role_assignment" "keyvault_writer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

# Rol para LEER secretos (App Service)
resource "azurerm_role_assignment" "keyvault_reader" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

# ============================================================
# 2. SECRETOS DE LARAVEL EN KEY VAULT
# ============================================================

# APP_KEY de Laravel (clave simulada)
resource "azurerm_key_vault_secret" "app_key" {
  name         = "app-key"
  value        = "base64:123456789ABCDEF123456789ABCDEF123456789ABCDEF123456789ABCDEF"
  key_vault_id = azurerm_key_vault.kv.id
}

# Host del servidor SQL
resource "azurerm_key_vault_secret" "db_host" {
  name         = "db-host"
  value        = azurerm_mssql_server.sql_server.fully_qualified_domain_name
  key_vault_id = azurerm_key_vault.kv.id
}

# Nombre de la base de datos
resource "azurerm_key_vault_secret" "db_name" {
  name         = "db-name"
  value        = azurerm_mssql_database.db.name
  key_vault_id = azurerm_key_vault.kv.id
}

# Usuario del servidor SQL
resource "azurerm_key_vault_secret" "db_user" {
  name         = "db-user"
  value        = azurerm_mssql_server.sql_server.administrator_login
  key_vault_id = azurerm_key_vault.kv.id
}

# Contraseña del SQL (ahora segura desde variable)
resource "azurerm_key_vault_secret" "db_pass" {
  name         = "db-pass"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.kv.id
}

# ============================================================
# 3. CONFIGURACIÓN DE VARIABLES DEL APP SERVICE (KEY VAULT)
# ============================================================

resource "azurerm_linux_web_app" "app_settings_update" {
  name                = azurerm_linux_web_app.app.name
  location            = azurerm_linux_web_app.app.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id

  app_settings = {
    WEBSITE_RUN_FROM_PACKAGE = "0"

    APP_ENV   = "production"
    APP_DEBUG = "false"
    APP_KEY   = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.app_key.id})"

    DB_CONNECTION = "mysql"
    DB_HOST       = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.db_host.id})"
    DB_PORT       = "3306"
    DB_DATABASE   = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.db_name.id})"
    DB_USERNAME   = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.db_user.id})"
    DB_PASSWORD   = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.db_pass.id})"
  }

  depends_on = [
    azurerm_role_assignment.terraform_admin,
    azurerm_role_assignment.keyvault_writer,
    azurerm_role_assignment.keyvault_reader
  ]
}

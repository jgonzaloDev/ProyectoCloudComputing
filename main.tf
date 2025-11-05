# ============================================================
# 0. DATOS EXISTENTES DE LA INFRAESTRUCTURA BASE
# ============================================================

# 🧱 Leer el grupo de recursos existente (no crear)
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

# 🧭 Leer el Key Vault existente
data "azurerm_key_vault" "kv" {
  name                = var.key_vault_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

# ⚙️ Leer el App Service Plan existente
data "azurerm_service_plan" "plan" {
  name                = var.app_service_plan_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

# 🌐 Leer el App Service (backend Laravel) existente
data "azurerm_linux_web_app" "app" {
  name                = var.app_service_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

# 💾 Leer el servidor SQL y la base de datos existentes
data "azurerm_mssql_server" "sql_server" {
  name                = var.sql_server_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_mssql_database" "db" {
  name                = var.database_name
  server_id           = data.azurerm_mssql_server.sql_server.id
}

# ============================================================
# 1. ROLES RBAC (Key Vault)
# ============================================================

# Rol ADMIN para la identidad de Terraform (GitHub OIDC o SPN)
resource "azurerm_role_assignment" "terraform_admin" {
  scope                = data.azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.terraform_principal_id
}

# Rol para CREAR / ACTUALIZAR / ELIMINAR secretos (App Service)
resource "azurerm_role_assignment" "keyvault_writer" {
  scope                = data.azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_linux_web_app.app.identity[0].principal_id
}

# Rol para LEER secretos (App Service)
resource "azurerm_role_assignment" "keyvault_reader" {
  scope                = data.azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.azurerm_linux_web_app.app.identity[0].principal_id
}

# ============================================================
# 2. SECRETOS DE LARAVEL EN KEY VAULT
# ============================================================

resource "azurerm_key_vault_secret" "app_key" {
  name         = "app-key"
  value        = "base64:123456789ABCDEF123456789ABCDEF123456789ABCDEF123456789ABCDEF"
  key_vault_id = data.azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "db_host" {
  name         = "db-host"
  value        = data.azurerm_mssql_server.sql_server.fully_qualified_domain_name
  key_vault_id = data.azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "db_name" {
  name         = "db-name"
  value        = data.azurerm_mssql_database.db.name
  key_vault_id = data.azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "db_user" {
  name         = "db-user"
  value        = data.azurerm_mssql_server.sql_server.administrator_login
  key_vault_id = data.azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "db_pass" {
  name         = "db-pass"
  value        = data.azurerm_mssql_server.sql_server.administrator_login_password
  key_vault_id = data.azurerm_key_vault.kv.id
}

# ============================================================
# 3. CONFIGURACIÓN DE VARIABLES DEL APP SERVICE (KEY VAULT)
# ============================================================

resource "azurerm_linux_web_app" "app_settings_update" {
  name                = data.azurerm_linux_web_app.app.name
  location            = data.azurerm_linux_web_app.app.location
  resource_group_name = data.azurerm_resource_group.rg.name
  service_plan_id     = data.azurerm_service_plan.plan.id

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

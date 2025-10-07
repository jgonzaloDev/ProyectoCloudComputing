terraform {
  required_version = ">= 1.7.0"
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

# =========================================================
# Resource Group
# =========================================================
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# =========================================================
# Networking: VNet + Subnets
# =========================================================
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.address_space
}

# Subnet Application Gateway
resource "azurerm_subnet" "subnet_ag" {
  name                 = "subnetAG"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_ag_cidr]
}

# Subnet integración (delegada a App Service)
resource "azurerm_subnet" "subnet_integration" {
  name                 = "subnet-integracion"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_integration_cidr]

  delegation {
    name = "webapp-delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
      ]
    }
  }
}

# Subnet Private Endpoint
resource "azurerm_subnet" "subnet_pe" {
  name                          = "subnet-privateEndPoint"
  resource_group_name           = azurerm_resource_group.rg.name
  virtual_network_name          = azurerm_virtual_network.vnet.name
  address_prefixes              = [var.subnet_privateendpoint_cidr]
  private_endpoint_network_policies = "Disabled"
}

# =========================================================
# App Service Plan (Windows S1) + Web App Windows (.NET 10 LTS)
# =========================================================
resource "azurerm_service_plan" "plan" {
  name                = var.app_service_plan_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Windows"
  sku_name            = "S1"   # Estándar S1 (1.75 GB RAM, 1 vCPU)
}

resource "azurerm_windows_web_app" "web" {
  name                = var.webapp_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id

  public_network_access_enabled = false

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on              = true
    vnet_route_all_enabled = true

    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v8.0"   # Runtime .NET 8 (LTS)
    }
  }

  app_settings = {
    WEBSITE_RUN_FROM_PACKAGE = "0"
  }
}

# VNet Integration
resource "azurerm_app_service_virtual_network_swift_connection" "web_integration" {
  app_service_id = azurerm_windows_web_app.web.id
  subnet_id      = azurerm_subnet.subnet_integration.id
}

# =========================================================
# SQL Server + Database
# =========================================================
resource "azurerm_mssql_server" "sql" {
  name                          = var.sql_server_name
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  version                       = "12.0"
  administrator_login           = var.sql_admin_login
  administrator_login_password  = var.sql_admin_password
  public_network_access_enabled = false
}

resource "azurerm_mssql_database" "db" {
  name           = var.sql_database_name
  server_id      = azurerm_mssql_server.sql.id
  sku_name       = "Basic"
  zone_redundant = false
}

# =========================================================
# Key Vault privado + RBAC
# =========================================================
resource "azurerm_key_vault" "kv" {
  name                        = var.key_vault_name
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = var.tenant_id
  sku_name                    = "standard"

  soft_delete_retention_days   = 7
  purge_protection_enabled     = false
  public_network_access_enabled = false
  enable_rbac_authorization    = true
}

resource "azurerm_role_assignment" "kv_secrets_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_windows_web_app.web.identity[0].principal_id
}

# =========================================================
# Private DNS Zones
# =========================================================
resource "azurerm_private_dns_zone" "pdz_web" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "pdz_sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "pdz_kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_web" {
  name                  = "link-webapp"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.pdz_web.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_sql" {
  name                  = "link-sql"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.pdz_sql.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_kv" {
  name                  = "link-kv"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.pdz_kv.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# =========================================================
# Private Endpoints
# =========================================================
resource "azurerm_private_endpoint" "pe_web" {
  name                = "pe-webapp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet_pe.id

  private_service_connection {
    name                           = "webapp-privatelink"
    private_connection_resource_id = azurerm_windows_web_app.web.id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }

  private_dns_zone_group {
    name                 = "webapp-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.pdz_web.id]
  }
}

resource "azurerm_private_endpoint" "pe_sql" {
  name                = "pe-sql"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet_pe.id

  private_service_connection {
    name                           = "sql-privatelink"
    private_connection_resource_id = azurerm_mssql_server.sql.id
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]
  }

  private_dns_zone_group {
    name                 = "sql-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.pdz_sql.id]
  }
}

resource "azurerm_private_endpoint" "pe_kv" {
  name                = "pe-keyvault"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet_pe.id

  private_service_connection {
    name                           = "kv-privatelink"
    private_connection_resource_id = azurerm_key_vault.kv.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "kv-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.pdz_kv.id]
  }
}

# =========================================================
# Application Gateway
# =========================================================
resource "azurerm_public_ip" "agw_pip" {
  name                = "agw-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

data "azurerm_network_interface" "pe_web_nic" {
  name                = azurerm_private_endpoint.pe_web.network_interface[0].name
  resource_group_name = azurerm_resource_group.rg.name
}

locals {
  webapp_pe_private_ip = data.azurerm_network_interface.pe_web_nic.ip_configuration[0].private_ip_address
}

resource "azurerm_application_gateway" "agw" {
  name                = "appgateway-amorrescate"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name = "Standard_v2"
    tier = "Standard_v2"
  }

  autoscale_configuration {
    min_capacity = 1
    max_capacity = 2
  }

  gateway_ip_configuration {
    name      = "gatewayipconfig"
    subnet_id = azurerm_subnet.subnet_ag.id
  }

  frontend_port {
    name = "port-80"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "feip"
    public_ip_address_id = azurerm_public_ip.agw_pip.id
  }

  backend_address_pool {
    name         = "pool-webapp-pe"
    ip_addresses = [local.webapp_pe_private_ip]
  }

  backend_http_settings {
    name                  = "bhs-http"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }

  http_listener {
    name                           = "listener-http"
    frontend_ip_configuration_name = "feip"
    frontend_port_name             = "port-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "rule-webapp"
    rule_type                  = "Basic"
    http_listener_name         = "listener-http"
    backend_address_pool_name  = "pool-webapp-pe"
    backend_http_settings_name = "bhs-http"
    priority                   = 10
  }
}

# =========================================================
# Outputs
# =========================================================
output "appgateway_public_ip" {
  value       = azurerm_public_ip.agw_pip.ip_address
  description = "IP pública del Application Gateway"
}

output "webapp_pe_private_ip" {
  value       = local.webapp_pe_private_ip
  description = "IP privado del Web App (Private Endpoint)"
}

output "sql_server_fqdn" {
  value = azurerm_mssql_server.sql.fully_qualified_domain_name
}

output "key_vault_id" {
  value = azurerm_key_vault.kv.id
}

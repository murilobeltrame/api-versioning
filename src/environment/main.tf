terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    azapi = {
      source = "azure/azapi"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

variable "region" {
  type        = string
  default     = "eastus"
  description = "Desired Region"
}

variable "rg_name" {
  type        = string
  description = "Desired Resource Group Name"
}

resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.region
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "mbclaw"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azapi_resource" "aca_env" {
  type      = "Microsoft.App/managedEnvironments@2022-03-01"
  name      = "mbcacaenv"
  parent_id = azurerm_resource_group.rg.id
  location  = azurerm_resource_group.rg.location
  body = jsonencode({
    properties = {
      appLogsConfiguration = {
        destination = "log-analytics"
        logAnalyticsConfiguration = {
          customerId = azurerm_log_analytics_workspace.law.workspace_id
          sharedKey  = azurerm_log_analytics_workspace.law.primary_shared_key
        }
      }
    }
  })
}

variable "container_apps" {
  type = list(object({
    name            = string
    image           = string
    tag             = string
    containerPort   = number
    ingress_enabled = bool
    min_replicas    = number
    max_replicas    = number
    cpu_requests    = number
    mem_requests    = string
  }))
  default = [{
    containerPort   = 80
    cpu_requests    = 0.5
    image           = "murilobeltrame/wineapi"
    tag             = "latest"
    ingress_enabled = true
    max_replicas    = 2
    mem_requests    = "1.0Gi"
    min_replicas    = 1
    name            = "wineapi"
  }]
}

resource "azapi_resource" "aca" {
  for_each  = { for ca in var.container_apps : ca.name => ca }
  type      = "Microsoft.App/containerApps@2022-03-01"
  parent_id = azurerm_resource_group.rg.id
  location  = azurerm_resource_group.rg.location
  name      = each.value.name
  body = jsonencode({
    properties = {
      managedEnvironmentId = azapi_resource.aca_env.id
      configuration = {
        ingress = {
          external   = each.value.ingress_enabled
          targetPort = each.value.ingress_enabled ? each.value.containerPort : null
        }
      }
      template = {
        containers = [{
          name  = "main"
          image = "${each.value.image}:${each.value.tag}"
          resources = {
            cpu    = each.value.cpu_requests
            memory = each.value.mem_requests
          }
        }]
        scale = {
          minReplicas = each.value.min_replicas
          maxReplicas = each.value.max_replicas
        }
      }
    }
  })
}

resource "azurerm_api_management" "apim" {
  name                = "mbcapim"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = "Vineyard Company"
  publisher_email     = "publisher@vineyard.local"

  sku_name = "Developer_1"
}

resource "azurerm_api_management_api_version_set" "apimwineapivs" {
  name                = "apimwineapivs"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  display_name        = "Wines API"
  versioning_scheme   = "Segment"
}

resource "azurerm_api_management_api" "apimwineapiv1" {
  name                = "wineapiv1"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "Wines API"
  path                = "wines"
  version             = "v1"
  version_set_id      = azurerm_api_management_api_version_set.apimwineapivs.id
  protocols           = ["http", "https"]

  import {
    content_format = "openapi+json"
    content_value  = file("${path.module}/swagger.v1.json")
  }
}

resource "azurerm_api_management_api" "api_v2" {
  name                = "wineapiv2"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  revision            = "2"
  display_name        = "Wines API"
  path                = "wines"
  version             = "v2"
  version_set_id      = azurerm_api_management_api_version_set.apimwineapivs.id
  protocols           = ["http", "https"]

  import {
    content_format = "openapi+json"
    content_value  = file("${path.module}/swagger.v2.json")
  }
}

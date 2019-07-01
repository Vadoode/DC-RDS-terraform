provider "azurerm" {
}

variable "resource-location" {
  type        = "string"
  default     = "australiasoutheast"
  description = "provide a location where to provision resources"
}
resource "azurerm_resource_group" "test-resource-group" {
  name     = "temp-resource-group"
  location = "${var.resource-location}"

      tags = {
        purpose = "Demo"        
    }
}

resource "azurerm_virtual_network" "test-network" {
    name                = "VNet"
    address_space       = ["192.168.58.0/24"]
    location            = "australiasoutheast"
    resource_group_name = "${azurerm_resource_group.test-resource-group.name}"

    tags = {
        purpose = "Demo"        
    }
}

resource "azurerm_subnet" "test-subnet" {
    name                 = "mySubnet"
    resource_group_name  = "${azurerm_resource_group.test-resource-group.name}"
    virtual_network_name = "${azurerm_virtual_network.test-network.name}"
    address_prefix       = "192.168.58.0/25"    
}

resource "azurerm_network_security_group" "test-nsg" {
    name                = "myNetworkSecurityGroup"
    location            = "australiasoutheast"
    resource_group_name = "${azurerm_resource_group.test-resource-group.name}"
    
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        purpose = "Demo"        
    }
}

output "sample-output" {
  value       = "${azurazurerm_network_security_group.test-nsg.description}"
  description = "bla bla"
  sensitive   = false
}


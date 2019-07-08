provider "azurerm" {
    version = "~>1.31"
}

variable "resource-location" {
  type        = "string"
  default     = "australiasoutheast"
  description = "provide a location where to provision resources"
}
variable  "ClientSitePublicIP" {
    type="string"
    default= "1.2.3.4"    
    description = "local IP address of the site to be used for STS connection"
}

variable  "ClientSiteName" {
    type="string"
    default= "MelbourneOffice"    
    description = "name of the site to be used for STS connection"
}

variable  "LocalNetworkPrefix" {
    type="string"
    default= "172.17.0.0/22"    
    description = "Address range for local site, to be used for STS connection"
}
variable  "ClientShortName" {
    type="string"
    default= "myClient"    
    description = "Client name, to be used in object names."
}

locals {
    rgLocation= "[resourceGroup().location]"
    AzureInfraNetwork= "10.10.0.0/23"
    ServersSubnet= "10.10.0.0/24"
    GatewaySubnet= "10.10.1.0/24"
    P2SSubnet="10.10.2.0/24"
    DCIPAddr= "10.10.0.4"
    RDS1IPAddr= "10.10.0.11"
    RDS2IPAddr= "10.10.0.12"
    adminUserName= "itsadmin"
    adminPassword= "ItCp5wd${var.ClientShortName}"
    DCVMSize ="Standard_B1s"
    RDSVMSize= "Standard_B1s"
    STSPublicIP= "[concat(parameters('clientShortName'), '-sts-azure-ip')]"
    STSConnectionName= "[concat(parameters('clientShortName'), '-AZ-STS-Connection')]"
    STSSharedKey= "[uniqueString(resourceGroup().id, parameters('clientSitePublicIP'))]"
}

resource "azurerm_resource_group" "test-resource-group" {
  name     = "test-resource-group"
  location = "${var.resource-location}"

      tags = {
        purpose = "Demo"        
    }
}

resource "azurerm_virtual_network" "virtual-network" {
    name                = "${var.ClientShortName}-az-network"
    address_space       = ["${local.AzureInfraNetwork}"]
    location            = "${var.resource-location}"
    resource_group_name =  "${azurerm_resource_group.test-resource-group.name}"
}
resource "azurerm_subnet" "ServersSubnet" {
  name                = "ServersSubnet"
  resource_group_name = "${azurerm_resource_group.test-resource-group.name}"
  virtual_network_name= "${azurerm_virtual_network.virtual-network.name}"

  address_prefix = "${local.ServersSubnet}"
}
resource "azurerm_subnet" "GatewaySubnet" {
  name                = "GatewaySubnet"
  resource_group_name = "${azurerm_resource_group.test-resource-group.name}"
  virtual_network_name= "${azurerm_virtual_network.virtual-network.name}"

  address_prefix = "${local.GatewaySubnet}"
}

resource "azurerm_virtual_machine" "DCServer" {
  name                  = "${var.ClientShortName}-az-DC"
 location              = "${var.resource-location}"
  resource_group_name   = "${azurerm_resource_group.test-resource-group.name}"
  network_interface_ids = ["${azurerm_network_interface.DCNIC.id}"]
  vm_size               = "${local.DCVMSize}"

  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter-smalldisk"
    version   = "latest"
  }
  storage_os_disk {
    name              = "dc_osdisk_${var.ClientShortName}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "${var.ClientShortName}-az-dc"
    admin_username = "${local.adminUserName}"
    admin_password = "${local.adminPassword}"
  }
  os_profile_windows_config {
    provision_vm_agent = true
    enable_automatic_upgrades = true
    timezone = "AUS Eastern Standard Time"
    }
}
resource "azurerm_network_interface" "DCNIC" {
  name                = "dc-network-interface"
  location            = "${var.resource-location}"
  resource_group_name = "${azurerm_resource_group.test-resource-group.name}"

  ip_configuration {
    name                          = "ipconfig1" 
    subnet_id                     = "${azurerm_subnet.ServersSubnet.id}"
    private_ip_address_allocation = "Static"
    private_ip_address = "${local.DCIPAddr}" 
    primary = true       
  }

  enable_accelerated_networking = false
  enable_ip_forwarding = false
  dns_servers = ["127.0.0.1","8.8.8.8"]          
}

resource "azurerm_availability_set" "RDSAvailabilitySet" {
  location =   "${var.resource-location}"
  resource_group_name   = "${azurerm_resource_group.test-resource-group.name}"
  name = "RDSAvailabilitySet"

  platform_fault_domain_count = 2
  platform_update_domain_count = 2  
}

resource "azurerm_virtual_machine" "RDS1Server" {
  name                  = "${var.ClientShortName}-az-rds1"
 location              = "${var.resource-location}"
  resource_group_name   = "${azurerm_resource_group.test-resource-group.name}"
  network_interface_ids = ["${azurerm_network_interface.RDS1NIC.id}"]
  vm_size               = "${local.RDSVMSize}"
  availability_set_id = "${azurerm_availability_set.RDSAvailabilitySet.id}"

  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter-smalldisk"
    version   = "latest"
  }
  storage_os_disk {
    name              = "rds1_osdisk_${var.ClientShortName}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "${var.ClientShortName}-az-rds1"
    admin_username = "${local.adminUserName}"
    admin_password = "${local.adminPassword}"
  }
  os_profile_windows_config {
    provision_vm_agent = true
    enable_automatic_upgrades = true
    timezone = "AUS Eastern Standard Time"    
    }
}
resource "azurerm_network_interface" "RDS1NIC" {
  name                = "rds1-network-interface"
  location            = "${var.resource-location}"
  resource_group_name = "${azurerm_resource_group.test-resource-group.name}"

  ip_configuration {
    name                          = "ipconfig1" 
    subnet_id                     = "${azurerm_subnet.ServersSubnet.id}"
    private_ip_address_allocation = "Static"
    private_ip_address = "${local.RDS1IPAddr}" 
    primary = true       
  }
  
  enable_accelerated_networking = false
  enable_ip_forwarding = false
  dns_servers = ["${local.DCIPAddr}"]          
}


resource "azurerm_virtual_machine" "RDS2Server" {
  name                  = "${var.ClientShortName}-az-rds2"
 location              = "${var.resource-location}"
  resource_group_name   = "${azurerm_resource_group.test-resource-group.name}"
  network_interface_ids = ["${azurerm_network_interface.RDS2NIC.id}"]
  vm_size               = "${local.RDSVMSize}"
  availability_set_id = "${azurerm_availability_set.RDSAvailabilitySet.id}"

  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter-smalldisk"
    version   = "latest"
  }
  storage_os_disk {
    name              = "rds2_osdisk_${var.ClientShortName}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "${var.ClientShortName}-az-rds2"
    admin_username = "${local.adminUserName}"
    admin_password = "${local.adminPassword}"
  }
  os_profile_windows_config {
    provision_vm_agent = true
    enable_automatic_upgrades = true
    timezone = "AUS Eastern Standard Time"    
    }
}
resource "azurerm_network_interface" "RDS2NIC" {
  name                = "rds2-network-interface"
  location            = "${var.resource-location}"
  resource_group_name = "${azurerm_resource_group.test-resource-group.name}"

  ip_configuration {
    name                          = "ipconfig1" 
    subnet_id                     = "${azurerm_subnet.ServersSubnet.id}"
    private_ip_address_allocation = "Static"
    private_ip_address = "${local.RDS2IPAddr}" 
    primary = true       
  }
  
  enable_accelerated_networking = false
  enable_ip_forwarding = false
  dns_servers = ["${local.DCIPAddr}"]          
}


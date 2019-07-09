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

## Create a VNet and two subnets for it.
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
## Create one DC server and two RDS servers.
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

## STS VPN 

# Public IP for Virtual Network Gateway (STS Azure Side)
resource "azurerm_public_ip" "VNG-Public-IP" {
  name                = "${var.STSPublicIP}"
  location            = "${var.resource-location}"
  resource_group_name = "${azurerm_resource_group.test-resource-group.name}"

  ip_version = "IPv4"
  allocation_method   = "Dynamic"
  sku = "Basic"
  idle_timeout_in_minutes = 4  
}

# Virtual network gateway 
resource "azurerm_virtual_network_gateway" "VNG" {
  name                = "${var.clientSiteName}-STS-Azure-Side-GW"
  location            = "${var.resource-location}"
  resource_group_name = "${azurerm_resource_group.test-resource-group.name}"

  type     = "Vpn"
  vpn_type = "RouteBased"
  active_active = false
  enable_bgp    = false
  sku           = "Basic"
  
  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = "${azurerm_public_ip.VNG.it}"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = "${azurerm_subnet.GatewaySubnet.id}"
  }

  vpn_client_configuration {
    address_space = ["${var.P2SSubnet}"]
    root_certificate {
      name = "certp2sroot"
      public_cert_data  = "MIIC5zCCAc+gAwIBAgIQQAGCRSy+ua1P+qDjezo67TANBgkqhkiG9w0BAQsFADAWMRQwEgYDVQQDDAtQMlNSb290Q2VydDAeFw0xODEyMjUwMDQ5NTZaFw0xOTEyMjUwMTA5NTZaMBYxFDASBgNVBAMMC1AyU1Jvb3RDZXJ0MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqnUld2C6ZfzSGel9+qaclRhZipboT7aQnvWUAMwgRzCV/xZC8SxCaSMyBRgynO04nkkJ8M5VIk4OYIcrR+03rYtxazDbooF25FEGkyp0WxqJtkMD0/kaSpNehAntqW3xK1fy+8Q4BuE2KhVFl80E68VIQjxo/WzMj94YKuSGfAfy5jnCkkAFiMBZa15AlxjjlUafYg7nLlgiA0VcGN8QKeLsDE4MIF+skZW7/+Msh15sTrvY9dCaJD07DQFHYTb+SoC3EoFeONiNLBYvi+9afTOuVTbrKOaNh7XtOpAXh5fVjpsnMdHyy3MIYyaeMVidAZNXOjwC4c4JFz3+e2bV9QIDAQABozEwLzAOBgNVHQ8BAf8EBAMCAgQwHQYDVR0OBBYEFCROvLjTh8HYBoBKZE4BQltf4TXOMA0GCSqGSIb3DQEBCwUAA4IBAQCk/7VIQFjFOIqy52/TRGr7WjWAdQmCOnjjNaQN1KiIQp5qoO1Qo7kCpMIX0mzkg2wGEruYc6WOEtMiBHoaB3h5x4kMx9jj8JgAwTI4RPCGIwZv2JP2C4g2Ahd6iKOeZzKvpcNRqeBrTwiCiIu3j64qrna4Kzf87fxV1yjJAUT9igx9UXVfRCjkHLRn3qgEjsOXr/aTukjvrolRPBmNOgVjgkOsuDJJVq1NTbO9YhSq4VIO4PnWyoUz8L6zWXfIVRIjy/O1LC49L09yzk0wk+G6oulwjUwZFmHnkik7nV9vCOkn2dDkmxMw8vJ6PkvJQvRWjYP60nC0g1OsoVcIMovP"

    }
  }
}
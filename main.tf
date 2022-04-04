terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true
  features {}
}

resource "azurerm_resource_group" "rg-aulainfracloud" {
  name     = "aulainfracloudterraformtest"
  location = var.location
}

resource "azurerm_virtual_network" "vnet-aulainfra" {
    name                = "vnet-aula"
    resource_group_name = azurerm_resource_group.rg-aulainfracloud.name
    location            = azurerm_resource_group.rg-aulainfracloud.location
    address_space       = ["10.0.0.0/16"]

    tags = {
        enviroment = "Production"
        faculdade = "Impacta"
        turma = "ES23"
    }
}

resource "azurerm_subnet" "sub-aulainfra" {
  name                 = "sub-aula"
  resource_group_name  = azurerm_resource_group.rg-aulainfracloud.name
  virtual_network_name = azurerm_virtual_network.vnet-aulainfra.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "ip-aulainfra" {
  name                = "ip-aula"
  resource_group_name = azurerm_resource_group.rg-aulainfracloud.name
  location            = azurerm_resource_group.rg-aulainfracloud.location
  allocation_method   = "Static"

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_security_group" "nsc-aulainfra" {
  name                = "nsc-aula"
  location            = azurerm_resource_group.rg-aulainfracloud.location
  resource_group_name = azurerm_resource_group.rg-aulainfracloud.name

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

  security_rule {
    name                       = "web"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_interface" "nic-aulainfra" {
  name                = "example-nic"
  location            = azurerm_resource_group.rg-aulainfracloud.location
  resource_group_name = azurerm_resource_group.rg-aulainfracloud.name

  ip_configuration {
    name                          = "ip-aula-nic"
    subnet_id                     = azurerm_subnet.sub-aulainfra.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip-aulainfra.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsc-nic-aulainfra" {
  network_interface_id      = azurerm_network_interface.nic-aulainfra.id
  network_security_group_id = azurerm_network_security_group.nsc-aulainfra.id
}

resource "azurerm_virtual_machine" "vm-aulainfra" {
  name                  = "vm-aulainfra"
  location              = azurerm_resource_group.rg-aulainfracloud.location
  resource_group_name   = azurerm_resource_group.rg-aulainfracloud.name
  network_interface_ids = [azurerm_network_interface.nic-aulainfra.id]
  vm_size               = "Standard_DS1_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = var.adminuser
    admin_password = var.adminpassword
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "staging"
  }
}

data "azurerm_public_ip" "ip-aula" {
    name = azurerm_public_ip.ip-aulainfra.name
    resource_group_name = azurerm_resource_group.rg-aulainfracloud.name
}

resource "null_resource" "install-apache" {
    connection {
        type = "ssh"
        host = data.azurerm_public_ip.ip-aula.ip_address
        user = var.user
        password = var.password
    }

    provisioner "remote-exec" {
        inline = [
            "sudo apt update",
            "sudo apt install -y apache2",
        ]
    }

    depends_on = [
        azurerm_virtual_machine.vm-aulainfra
    ]
}

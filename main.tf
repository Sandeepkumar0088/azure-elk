provider "azurerm" {
  features {}
}
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
resource "azurerm_resource_group" "elk" {
  name = "elk-rg"
  location = "Central India"
}
resource "azurerm_virtual_network" "elk_vnet" {
  name                = "elk-vnet"
  location            = azurerm_resource_group.elk.location
  resource_group_name = azurerm_resource_group.elk.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "elk_subnet" {
  name                 = "elk-subnet"
  resource_group_name  = azurerm_resource_group.elk.name
  virtual_network_name = azurerm_virtual_network.elk_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}
resource "azurerm_public_ip" "elk_pip" {
  name                = "elk-pip"
  location            = azurerm_resource_group.elk.location
  resource_group_name = azurerm_resource_group.elk.name
  allocation_method   = "Static"
}

resource "azurerm_network_security_group" "elk_nsg" {
  name                = "elk-nsg"
  location            = azurerm_resource_group.elk.location
  resource_group_name = azurerm_resource_group.elk.name

  # Allow ALL inbound traffic
  security_rule {
    name                       = "Allow-All-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"

    source_port_range          = "*"
    destination_port_range     = "*"

    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }

  # Allow ALL outbound traffic
  security_rule {
    name                       = "Allow-All-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "elk_nic" {

  name                = "elk-nic"
  location            = azurerm_resource_group.elk.location
  resource_group_name = azurerm_resource_group.elk.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.elk_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.elk_pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "elk" {

  network_interface_id      = azurerm_network_interface.elk_nic.id
  network_security_group_id = azurerm_network_security_group.elk_nsg.id
}

resource "azurerm_linux_virtual_machine" "elk_vm" {
  name                = "elk-vm"
  resource_group_name = azurerm_resource_group.elk.name
  location            = azurerm_resource_group.elk.location
  size                = "Standard_D4ls_v6"

  admin_username                  = "sandeep"
  admin_password                  = "Sandeep.,@0088"
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.elk_nic.id
  ]
  # identity {
  #   type = "SystemAssigned"
  # }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "almalinux"
    offer     = "almalinux-x86_64"
    sku       = "9-gen2"
    version   = "latest"
  }
}

resource "null_resource" "elk" {

  depends_on = [
    azurerm_linux_virtual_machine.elk_vm
  ]

  connection {
    type     = "ssh"
    host     = azurerm_linux_virtual_machine.elk_vm.public_ip_address
    user     = "sandeep"
    password = "Sandeep.,@0088"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo dnf install -y ansible-core npm unzip git",
      "ansible-pull -i ${azurerm_linux_virtual_machine.elk_vm.public_ip_address}, --limit all -U https://github.com/Sandeepkumar0088/azure-elk.git elk.yml -e ansible_user=sandeep -e ansible_password=Sandeep.,@0088"

    ]
  }
}


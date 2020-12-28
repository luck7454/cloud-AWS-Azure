provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "Ihor" {
  name     = "GLHW"
  location = "westeurope"
}
resource "azurerm_virtual_network" "VN" {
  name                = "VN"
  location            = azurerm_resource_group.Ihor.location
  address_space       = ["10.0.0.0/16"]
  resource_group_name = azurerm_resource_group.Ihor.name
}
resource "azurerm_subnet" "subnet1" {
 name                 = "subnet1"
 resource_group_name  = azurerm_resource_group.Ihor.name
 virtual_network_name = azurerm_virtual_network.Ihor.name
 address_prefixes     = ["10.0.1.0/24"]
}
resource "azurerm_public_ip" "azure-ip-adress" {
 name                         = "PublicIPAddress"
 location                     = azurerm_resource_group.Ihor.location
 resource_group_name          = azurerm_resource_group.Ihor.name
 allocation_method            = "Static"
}
resource "azurerm_lb" "azure_nginx_lb" {
 name                = "loadBalancer"
 location            = azurerm_resource_group.Ihor.location
 resource_group_name = azurerm_resource_group.Ihor.name

 frontend_ip_configuration {
   name                 = "subnet1"
   public_ip_address_id = azurerm_public_ip.azure-ip-adress.id
 }
}
resource "azurerm_lb_backend_address_pool" "azure_nginx_backend_address_pool" {
 resource_group_name = azurerm_resource_group.Ihor.name
 loadbalancer_id     = azurerm_lb.azure_nginx_lb.id
 name                = "backend_address_pool"
}

resource "azurerm_lb_nat_pool" "azure_nginx_nat" {
  resource_group_name            = azurerm_resource_group.Ihor.name
  loadbalancer_id                = azurerm_lb.azure_nginx_lb.id
  name                           = "azurerm_lb_nat_pool"
  protocol                       = "Tcp"
  frontend_port_start            = 80
  frontend_port_end              = 81
  backend_port                   = 8080
  frontend_ip_configuration_name = "subnet1"
}

resource "azurerm_network_interface" "nginx_nic" {
 count               = 2
 name                = "acctni${count.index}"
 location            = azurerm_resource_group.Ihor.location
 resource_group_name = azurerm_resource_group.Ihor.name

 ip_configuration {
   name                          = "testConfiguration"
   subnet_id                     = azurerm_subnet.azure_nginx_subnet.id
   private_ip_address_allocation = "dynamic"
 }
}

resource "azurerm_managed_disk" "nginx_disk" {
 count                = 2
 name                 = "datadisk_existing_${count.index}"
 location             = azurerm_resource_group.Ihor.location
 resource_group_name  = azurerm_resource_group.Ihor.name
 storage_account_type = "Standard_LRS"
 create_option        = "Empty"
 disk_size_gb         = "1023"
}

resource "azurerm_availability_set" "nginx_avset" {
 name                         = "avset"
 location                     = azurerm_resource_group.Ihor.location
 resource_group_name          = azurerm_resource_group.Ihor.name
 platform_fault_domain_count  = 2
 platform_update_domain_count = 2
 managed                      = true
}

resource "azurerm_virtual_machine" "nginx_vm" {
 count                 = 2
 name                  = "acctvm${count.index}"
 location              = azurerm_resource_group.Ihor.location
 availability_set_id   = azurerm_availability_set.nginx_avset.id
 resource_group_name   = azurerm_resource_group.Ihor.name
 network_interface_ids = [element(azurerm_network_interface.nginx_nic.*.id, count.index)]
 vm_size               = "Standard_DS1_v2"
}
storage_image_reference {
   publisher = "Canonical"
   offer     = "UbuntuServer"
   sku       = "18.04-LTS"
   version   = "latest"
 }

 storage_os_disk {
   name              = "myosdisk${count.index}"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }
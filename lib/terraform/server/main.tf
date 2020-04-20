data "ibm_is_vpc" "vpc" {
  name = var.vpc_name
}

data "ibm_is_subnet" "subnet" {
  identifier = var.subnet_id
}

data "ibm_is_image" "ubuntu_1804" {
  name = "ibm-ubuntu-18-04-64"
}

resource "ibm_is_instance" "server" {
  resource_group = var.resource_group_id

  name           = var.name
  image          = data.ibm_is_image.ubuntu_1804.id
  profile        = var.profile
  vpc            = data.ibm_is_vpc.vpc.id
  zone           = data.ibm_is_subnet.subnet.zone
  keys           = [ var.key_id ]
  user_data      = var.user_data

  primary_network_interface {
    name            = "eth0"
    subnet          = var.subnet_id
    security_groups = var.security_groups
  }
}

resource "ibm_is_floating_ip" "server_fip" {
  resource_group = var.resource_group_id
  name           = "${ibm_is_instance.server.name}-fip"
  target         = ibm_is_instance.server.primary_network_interface[ 0 ].id
}

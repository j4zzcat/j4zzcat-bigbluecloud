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
  keys           = var.keys
  user_data      = var.user_data

  primary_network_interface {
    name            = "eth0"
    subnet          = var.subnet_id
    security_groups = var.security_groups
  }
}

resource "ibm_is_floating_ip" "server_fip" {
  count = var.fip == true ? 1 : 0

  name           = "${ibm_is_instance.server.name}-fip"
  target         = ibm_is_instance.server.primary_network_interface[ 0 ].id
  resource_group = var.resource_group_id
}

resource "null_resource" "j4zzcat_server_post_provision" {
  count = var.post_provision == null ? 0 : 1

  connection {
    type        = "ssh"
    user        = "root"
    private_key = var.post_provision[ "ssh_key" ]
    host        = var.fip ? ibm_is_floating_ip.server_fip[ 0 ].address : ibm_is_instance.server.primary_network_interface[ 0 ].primary_ipv4_address
  }

  provisioner "remote-exec" {
    inline = var.post_provision[ "inline" ]
  }
}

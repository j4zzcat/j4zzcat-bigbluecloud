####
# Some locals
#

locals {
  repo_home     = "https://github.com/j4zzcat/j4zzcat-ibmcloud"
  repo_home_raw = "https://raw.githubusercontent.com/j4zzcat/j4zzcat-ibmcloud/master"
}

####
# VPC, Subnet and Public Gateway
#

resource "ibm_is_vpc" "vpc" {
  resource_group = var.resource_group_id
  name           = var.name
  classic_access = var.classic_access
}

resource "ibm_is_public_gateway" "public_gateway" {
  resource_group = ibm_is_vpc.vpc.resource_group

  name     = "public-gateway"
  vpc      = ibm_is_vpc.vpc.id
  zone     = var.zone_name
}

resource "ibm_is_subnet" "vpc_subnet" {
  name                     = "vpc-subnet"
  vpc                      = ibm_is_vpc.vpc.id
  zone                     = var.zone_name
  public_gateway           = ibm_is_public_gateway.public_gateway.id
  total_ipv4_address_count = "256"
}

####
# Security Groups
# Inbound: members of the VPC
# Inbound: members of the 10.0.0./8 network (IaaS)
# Outbound: No restrictions
#

resource "ibm_is_security_group" "vpc_default" {
  resource_group = ibm_is_vpc.vpc.resource_group
  name = "${ibm_is_vpc.vpc.name}-default"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "vpc_default_sgri_self" {
  group      = ibm_is_security_group.vpc_default.id
  direction  = "inbound"
  remote     = ibm_is_security_group.vpc_default.id
}

resource "ibm_is_security_group_rule" "vpc_default_sgri_iaas" {
  count = var.classic_access ? 1 : 0

  group      = ibm_is_security_group.vpc_default.id
  direction  = "inbound"
  remote     = "10.0.0.0/8"
}

resource "ibm_is_security_group_rule" "vpc_default_sgro_any" {
  group      = ibm_is_security_group.vpc_default.id
  direction  = "outbound"
  remote     = "0.0.0.0/0"
}

####
# Bastion
#

resource "ibm_is_subnet" "bastion_subnet" {
  count = var.bastion ? 1 : 0

  name                     = "bastion-subnet"
  vpc                      = ibm_is_vpc.vpc.id
  zone                     = var.zone_name
  public_gateway           = ibm_is_public_gateway.public_gateway.id
  total_ipv4_address_count = "256"
}

####
# Bastion security groups
# Inbound: Ping from anywhere
# Inbound: SSH from specified CIDR
# Outbound: No restrictions
#

resource "ibm_is_security_group" "bastion_default" {
  count = var.bastion ? 1 : 0

  resource_group = ibm_is_vpc.vpc.resource_group
  name = "${ibm_is_vpc.vpc.name}-bastion-default"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "vpc_default_sgri_bastion" {
  count = var.bastion ? 1 : 0

  group      = ibm_is_security_group.vpc_default.id
  direction  = "inbound"
  remote     = ibm_is_security_group.bastion_default[ 0 ].id
}

resource "ibm_is_security_group_rule" "bastion_default_sgri_ping" {
  group      = ibm_is_security_group.bastion_default[ 0 ].id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  icmp {
    code = 0
    type = 8
  }
}

resource "ibm_is_security_group_rule" "bastion_default_sgri_ssh" {
  group      = ibm_is_security_group.bastion_default[ 0 ].id
  direction  = "inbound"
  remote     = "0.0.0.0/0" # TODO tighten

  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "bastion_default_sgro_outbound" {
  group      = ibm_is_security_group.bastion_default[ 0 ].id
  direction  = "outbound"
  remote     = "0.0.0.0/0"
}

data "ibm_is_image" "ubuntu_1804" {
  name = "ibm-ubuntu-18-04-64"
}

resource "ibm_is_ssh_key" "bastion_key" {
  count = var.bastion ? 1 : 0

  name           = "${ibm_is_vpc.vpc.name}-bastion-key"
  public_key     = file( "${var.bastion_key}.pub" )
  resource_group = var.resource_group_id
}

resource "ibm_is_instance" "bastion_server" {
  count = var.bastion ? 1 : 0

  name           = "${ibm_is_vpc.vpc.name}-bastion"
  image          = data.ibm_is_image.ubuntu_1804.id
  profile        = "bx2-2x8"
  vpc            = ibm_is_vpc.vpc.id
  zone           = ibm_is_subnet.bastion_subnet[ 0 ].zone
  keys           = [ ibm_is_ssh_key.bastion_key[ 0 ].id ]
  resource_group = var.resource_group_id

  primary_network_interface {
    name            = "eth0"
    subnet          = ibm_is_subnet.bastion_subnet[ 0 ].id
    security_groups = [ ibm_is_security_group.bastion_default[ 0 ].id ]
  }
}

resource "ibm_is_floating_ip" "bastion_server_fip" {
  count = var.bastion ? 1 : 0

  name           = "${ibm_is_instance.bastion_server[ 0 ].name}-fip"
  target         = ibm_is_instance.bastion_server[ 0 ].primary_network_interface[ 0 ].id
  resource_group = var.resource_group_id

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file( var.bastion_key )
    host        = ibm_is_floating_ip.bastion_server_fip[ 0 ].address
  }

  provisioner "remote-exec" {
    scripts = [
      "${path.module}/../../scripts/ubuntu_18/upgrade_os.sh",
      "${path.module}/../../scripts/ubuntu_18/do_reboot.sh" ]
  }

  provisioner "local-exec" {
    command = "sleep 15"
  }

  provisioner "remote-exec" {
    inline = [ "echo 'Dummy!'" ]
  }
}

# resource "ibm_is_network_acl" "l1v_conn_with_l1i" {
#   provider = ibm.l1
#
#   name = "l1v-conn-with-l1i"
#   vpc  = ibm_is_vpc.l1v_vpc.id
#
#   rules {
#     name        = "outbound"
#     action      = "allow"
#     source      = "0.0.0.0/0"
#     destination = "0.0.0.0/0"
#     direction   = "outbound"
#   }
#
#   rules {
#     name        = "inbound"
#     action      = "allow"
#     source      = "0.0.0.0/0"
#     destination = "0.0.0.0/0"
#     direction   = "inbound"
#   }
# }

# ---- cloud object storage ---
# resource "ibm_iam_authorization_policy" "l1v_vpc_image_reader_g_cos" {
#   source_service_name         = "is"
#   source_resource_type        = "image"
#   source_resource_instance_id = ibm_is_vpc.l1v_vpc.id
#
#   target_service_name         = "cloud-object-storage"
#   target_resource_instance_id = ibm_resource_instance.g_cos.id
#   roles                       = [ "Reader" ]
# }
#
# resource "ibm_resource_instance" "g_cos" {
#   provider          = ibm.l1
#   tags              = [ local.fqdn ]
#   resource_group_id = ibm_resource_group.g_resource_group.id
#
#   name              = join( "-", [ var.cluster_name, "cos" ] )
#   service           = "cloud-object-storage"
#   plan              = "standard"
#   location          = "global"
# }

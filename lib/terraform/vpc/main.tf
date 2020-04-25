resource "ibm_is_vpc" "vpc" {
  resource_group = var.resource_group_id
  name           = var.name
  classic_access = var.classic_access
}

resource "ibm_is_public_gateway" "public_gateway" {
  resource_group = ibm_is_vpc.vpc.resource_group

  name     = "${ibm_is_vpc.vpc.name}-public-gateway"
  vpc      = ibm_is_vpc.vpc.id
  zone     = var.zone_name
}

resource "ibm_is_subnet" "default_subnet" {
  name           = "default-subnet"
  vpc            = ibm_is_vpc.vpc.id
  zone           = var.zone_name
  public_gateway = ibm_is_public_gateway.public_gateway.id
  total_ipv4_address_count = "256"
}

####
# Security Groups
#

# --- any_to_any ---
resource "ibm_is_security_group" "allow_any_to_any" {
  resource_group = ibm_is_vpc.vpc.resource_group
  name = "allow-any-to-any"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "allow_outbound_to_any_rule" {
  group      = ibm_is_security_group.allow_any_to_any.id
  direction  = "outbound"
  remote     = "0.0.0.0/0"
}

resource "ibm_is_security_group_rule" "allow_inbound_from_any_rule" {
  group      = ibm_is_security_group.allow_any_to_any.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"
}

# --- allow basic operation ---
resource "ibm_is_security_group" "allow_basic_operation" {
  resource_group = ibm_is_vpc.vpc.resource_group
  name = "allow-basic-operation"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "allow_basic_operation_outbound_to_any_rule" {
  group      = ibm_is_security_group.allow_basic_operation.id
  direction  = "outbound"
  remote     = "0.0.0.0/0"
}

resource "ibm_is_security_group_rule" "allow_basic_operation_icmp_rule" {
  group      = ibm_is_security_group.allow_basic_operation.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  icmp {
    code = 0
    type = 8
  }
}

# --- allow outbound to any ---
resource "ibm_is_security_group" "allow_outbound_any" {
  resource_group = ibm_is_vpc.vpc.resource_group
  name = "allow-outbound-any"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "allow_outbound_to_any_rule_2" {
  group      = ibm_is_security_group.allow_outbound_any.id
  direction  = "outbound"
  remote     = "0.0.0.0/0"
}

# --- allow inbound ping ---
resource "ibm_is_security_group" "allow_inbound_ping" {
  resource_group = ibm_is_vpc.vpc.resource_group
  name = "allow-inbound-ping"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "icmp_rule" {
  group      = ibm_is_security_group.allow_inbound_ping.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  icmp {
    code = 0
    type = 8
  }
}

# --- allow inbound http/https ---
resource "ibm_is_security_group" "allow_inbound_http_https" {
  resource_group = ibm_is_vpc.vpc.resource_group

  name = "allow-inbound-http-https"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "http_rule" {
  group      = ibm_is_security_group.allow_inbound_http_https.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 80
    port_max = 80
  }
}

resource "ibm_is_security_group_rule" "https_rule" {
  group      = ibm_is_security_group.allow_inbound_http_https.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 443
    port_max = 443
  }
}

# --- allow inbound ssh ---
resource "ibm_is_security_group" "allow_inbound_ssh" {
  resource_group = ibm_is_vpc.vpc.resource_group
  name = "allow-inbound-ssh"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "ssh_rule" {
  group      = ibm_is_security_group.allow_inbound_ssh.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 22
    port_max = 22
  }
}

# --- allow inbound dns ---
resource "ibm_is_security_group" "allow_inbound_dns" {
  resource_group = ibm_is_vpc.vpc.resource_group
  name = "allow-inbound-dns"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "dns_tcp_rule" {
  group      = ibm_is_security_group.allow_inbound_dns.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 53
    port_max = 53
  }
}

resource "ibm_is_security_group_rule" "dns_udp_rule" {
  group      = ibm_is_security_group.allow_inbound_dns.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  udp {
    port_min = 53
    port_max = 53
  }
}

# --- allow inbound dhcp ---
resource "ibm_is_security_group" "allow_inbound_dhcp" {
  resource_group = ibm_is_vpc.vpc.resource_group
  name = "allow-inbound-dhcp"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "dhcp_rule" {
  group      = ibm_is_security_group.allow_inbound_dhcp.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  udp {
    port_min = 67
    port_max = 67
  }
}

####
# Bastion
#

resource "ibm_is_subnet" "bastion_subnet" {
  count          = var.bastion ? 1 : 0

  name           = "bastion-subnet"
  vpc            = ibm_is_vpc.vpc.id
  zone           = var.zone_name
  public_gateway = ibm_is_public_gateway.public_gateway.id
  total_ipv4_address_count = "256"
}

data "ibm_is_image" "ubuntu_1804" {
  name = "ibm-ubuntu-18-04-64"
}

resource "ibm_is_ssh_key" "bastion_key" {
  name           = "${ibm_is_vpc.vpc.name}-bastion-key"
  public_key     = file( var.bastion_public_key )
  resource_group = var.resource_group_id
}

module "bastion_server" {
  source = "../server"

  name              = "${ibm_is_vpc.vpc.name}-bastion-server"
  profile           = "bx2-2x8"
  vpc_name          = ibm_is_vpc.vpc.name
  subnet_id         = ibm_is_subnet.bastion_subnet[ 0 ].id
  fip               = true
  keys              = [ ibm_is_ssh_key.bastion_key.id ]
  resource_group_id = var.resource_group_id
  security_groups   = [ ibm_is_security_group.allow_basic_operation.id,
                        ibm_is_security_group.allow_inbound_ssh.id ]
  user_data = <<-EOT
    #cloud-config
    runcmd:
      - git clone https://github.com/j4zzcat/j4zzcat-ibmcloud.git /usr/local/src/j4zzcat-ibmcloud
      - bash /usr/local/src/j4zzcat-ibmcloud/lib/scripts/ubuntu_18/upgrade_os.sh
      - bash /usr/local/src/j4zzcat-ibmcloud/lib/scripts/ubuntu_18/install_ibmcloud_cli.sh
    power_state:
      mode: reboot
      condition: true
    EOT
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

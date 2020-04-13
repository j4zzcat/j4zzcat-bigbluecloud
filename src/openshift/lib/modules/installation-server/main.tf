provider "ibm" {
  region     = var.region_name
  generation = 2
}

data "ibm_is_vpc" "vpc" {
  name = var.vpc_name
}

data "ibm_is_subnet" "subnet_1" {
  identifier = var.subnet_id
}

data "ibm_is_ssh_key" "admin_public_key" {
  name = join( "-", [ var.vpc_name, "admin-key" ] )
}

data "ibm_is_image" "ubuntu_1804" {
  name = "ibm-ubuntu-18-04-64"
}

resource "ibm_is_security_group" "installation_server" {
  resource_group = ibm_is_vpc.vpc.resource_group

  name = "installation-server"
  vpc  = ibm_is_vpc.vpc.id
}

# TODO harden
resource "ibm_is_security_group_rule" "outbound_rule" {
  group      = ibm_is_security_group.installation_server.id
  direction  = "outbound"
  remote     = "0.0.0.0/0"
}

resource "ibm_is_security_group_rule" "ssh_rule_installation_server" {
  group      = ibm_is_security_group.installation_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "icmp_rule_installation_server" {
  group      = ibm_is_security_group.installation_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  icmp {
    code = 0
    type = 8
  }
}

resource "ibm_is_security_group_rule" "dns_rule_installation_server" {
  group      = ibm_is_security_group.installation_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 53
    port_max = 53
  }
}

resource "ibm_is_security_group_rule" "dhcp_rule_installation_server" {
  group      = ibm_is_security_group.installation_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  udp {
    port_min = 67
    port_max = 67
  }
}

resource "ibm_is_security_group_rule" "http_rule_installation_server" {
  group      = ibm_is_security_group.installation_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 80
    port_max = 80
  }
}

resource "ibm_is_security_group_rule" "sinatra_rule_installation_server" {
  group      = ibm_is_security_group.installation_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 8070
    port_max = 8070
  }
}

resource "ibm_is_instance" "installation_server" {
  tags           = null
  resource_group = ibm_is_vpc.vpc.resource_group
  depends_on     = [ ibm_is_security_group.installation_server ]

  name       = "installation-server"
  image      = data.ibm_is_image.ubuntu_1804.id
  profile    = "bx2-2x8"
  primary_network_interface {
    name     = "eth0"
    subnet   = ibm_is_subnet.subnet_1.id
    security_groups = [ ibm_is_security_group.installation_server.id ]
  }
  vpc        = ibm_is_vpc.vpc.id
  zone       = ibm_is_subnet.subnet_1.zone
  keys       = [ ibm_is_ssh_key.admin_public_key.id ]
  user_data  = <<-EOT
    #cloud-config
    runcmd:
      - git clone https://github.com/j4zzcat/j4zzcat-ibmcloud.git /usr/local/src
      - bash /usr/local/src/j4zzcat-ibmcloud/src/openshift/lib/modules/installation-server/post-provision.sh

    power_state:
      mode: reboot
      timeout: 1
      condition: True
    EOT

}

resource "ibm_is_floating_ip" "installation_server" {
  tags           = null
  resource_group = ibm_is_vpc.vpc.resource_group
  depends_on     = [ ibm_is_instance.installation_server ]

  name   = "installation-server"
  target = ibm_is_instance.installation_server.primary_network_interface[ 0 ].id

}

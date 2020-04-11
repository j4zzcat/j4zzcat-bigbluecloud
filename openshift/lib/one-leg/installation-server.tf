data "ibm_is_image" "ubuntu_1804" {
  name = "ibm-ubuntu-18-04-64"
}

resource "ibm_is_security_group" "installation_server" {
  provider       = ibm.l1
  resource_group = ibm_is_vpc.l1v_vpc.resource_group

  name = "installation-server"
  vpc  = ibm_is_vpc.l1v_vpc.id

}

# TODO harden
resource "ibm_is_security_group_rule" "outbound_rule" {
  provider   = ibm.l1

  group      = ibm_is_security_group.installation_server.id
  direction  = "outbound"
  remote     = "0.0.0.0/0"
}

resource "ibm_is_security_group_rule" "ssh_rule_installation_server" {
  provider   = ibm.l1

  group      = ibm_is_security_group.installation_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "icmp_rule_installation_server" {
  provider   = ibm.l1

  group      = ibm_is_security_group.installation_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  icmp {
    code = 0
    type = 8
  }
}

resource "ibm_is_security_group_rule" "dns_rule_installation_server" {
  provider   = ibm.l1

  group      = ibm_is_security_group.installation_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 53
    port_max = 53
  }
}

resource "ibm_is_security_group_rule" "dhcp_rule_installation_server" {
  provider   = ibm.l1

  group      = ibm_is_security_group.installation_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  udp {
    port_min = 67
    port_max = 67
  }
}

resource "ibm_is_security_group_rule" "http_rule_installation_server" {
  provider   = ibm.l1
  group      = ibm_is_security_group.installation_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 80
    port_max = 80
  }
}

resource "ibm_is_security_group_rule" "sinatra_rule_installation_server" {
  provider   = ibm.l1

  group      = ibm_is_security_group.installation_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 8070
    port_max = 8070
  }
}

resource "ibm_is_instance" "l1vs1_installation_server" {
  provider       = ibm.l1
  tags           = [ local.fqdn, "l1v", "s1" ]
  resource_group = ibm_is_vpc.l1v_vpc.resource_group
  depends_on     = [ ibm_is_security_group.installation_server ]

  name       = "installation-server-l1vs1"
  image      = data.ibm_is_image.ubuntu_1804.id
  profile    = "bx2-2x8"
  primary_network_interface {
    name     = "eth0"
    subnet   = ibm_is_subnet.l1v_subnet_1.id
    security_groups = [ ibm_is_security_group.installation_server.id ]
  }
  vpc        = ibm_is_vpc.l1v_vpc.id
  zone       = ibm_is_subnet.l1v_subnet_1.zone
  keys       = [ ibm_is_ssh_key.l1v_admin_ssh_key.id  ]
  user_data  = <<-EOT
    #cloud-config
    runcmd:
      - curl -sL ${local.installation_server_post_install_script_url}

    power_state:
      mode: reboot
      timeout: 1
      condition: True
    EOT

}

resource "ibm_is_floating_ip" "l1vs1_installation_server_fip" {
  provider       = ibm.l1
  tags           = [ local.fqdn, "l1v", "s1" ]
  resource_group = ibm_is_vpc.l1v_vpc.resource_group
  depends_on     = [ ibm_is_instance.l1vs1_installation_server ]

  name   = "installation-server-l1vs1"
  target = ibm_is_instance.l1vs1_installation_server.primary_network_interface[ 0 ].id

}

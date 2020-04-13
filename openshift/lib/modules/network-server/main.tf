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

resource "ibm_is_security_group" "network_server" {
  resource_group = data.ibm_is_vpc.vpc.resource_group

  name = "network-server"
  vpc  = data.ibm_is_vpc.vpc.id
}

# TODO harden
resource "ibm_is_security_group_rule" "outbound_rule" {
  group      = ibm_is_security_group.network_server.id
  direction  = "outbound"
  remote     = "0.0.0.0/0"
}

resource "ibm_is_security_group_rule" "ssh_rule_installation_server" {
  group      = ibm_is_security_group.network_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "icmp_rule_network_server" {
  group      = ibm_is_security_group.network_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  icmp {
    code = 0
    type = 8
  }
}

resource "ibm_is_security_group_rule" "dns_rule_network_server" {
  group      = ibm_is_security_group.network_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 53
    port_max = 53
  }
}

resource "ibm_is_security_group_rule" "dhcp_network_server" {
  group      = ibm_is_security_group.network_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  udp {
    port_min = 67
    port_max = 67
  }
}

resource "ibm_is_instance" "network_server" {
  resource_group = data.ibm_is_vpc.vpc.resource_group

  name       = "network-server"
  image      = data.ibm_is_image.ubuntu_1804.id
  profile    = "bx2-2x8"

  primary_network_interface {
    name     = "eth0"
    subnet   = data.ibm_is_subnet.subnet_1.id
    security_groups = [ ibm_is_security_group.network_server.id ]
  }

  vpc        = data.ibm_is_vpc.vpc.id
  zone       = data.ibm_is_subnet.subnet_1.zone
  keys       = [ data.ibm_is_ssh_key.admin_public_key.id ]
  user_data  = <<-EOT
    #cloud-config
    runcmd:
      - git clone https://github.com/j4zzcat/j4zzcat-ibmcloud.git /usr/local/src/j4zzcat-ibmcloud
      - bash /usr/local/src/j4zzcat-ibmcloud/openshift/lib/modules/network-server/post-provision.sh

    power_state:
      mode: reboot
      timeout: 1
      condition: True
    EOT
}

resource "ibm_is_floating_ip" "l1vs1_network_server_fip" {
  resource_group = data.ibm_is_vpc.vpc.resource_group
  depends_on     = [ ibm_is_instance.network_server ]

  name   = "network-server"
  target = ibm_is_instance.network_server.primary_network_interface[ 0 ].id
}

# iaas
# resource "ibm_compute_vm_instance" "l1iv1s1_network_server" {
#   provider = ibm.l1
#   tags     = [ local.fqdn, "l1i", "v1", "s1" ]
#
#   hostname = "network-server-l1iv1s1"
#   domain   = local.fqdn
#
#   os_reference_code       = "UBUNTU_18_64"
#   # image_id                = "2354286" # https://cloud.ibm.com/gen1/infrastructure/image-templates/2354286/details#main
#   datacenter              = var.l1i_datacenter
#   network_speed           = 100
#   hourly_billing          = true
#   private_network_only    = false
#   cores                   = 1
#   memory                  = 1024
#   disks                   = [ 25 ]
#   local_disk              = false
#   private_vlan_id         = ibm_network_vlan.l1i_vlan_1.id
#   ssh_key_ids             = [ ibm_compute_ssh_key.l1i_admin_ssh_key.id ]
#   post_install_script_uri = local.network_server_post_install_script_url
# }
#
# resource "ibm_network_interface_sg_attachment" "l1i_sg_network_server" {
#   provider = ibm.l1
#
#   security_group_id    = ibm_security_group.l1i_conn_with_l1v.id
#   network_interface_id = ibm_compute_vm_instance.l1iv1s1_network_server.public_interface_id
# }

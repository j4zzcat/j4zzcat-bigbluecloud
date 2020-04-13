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

resource "ibm_is_instance" "network_server" {
  resource_group = data.ibm_is_vpc.vpc.resource_group

  name       = "network-server"
  image      = data.ibm_is_image.ubuntu_1804.id
  profile    = "bx2-2x8"
  primary_network_interface {
    name     = "eth0"
    subnet   = data.ibm_is_subnet.subnet_1.id
    security_groups = [
      var.security_groups_map[ "allow-outbound-any" ],
      var.security_groups_map[ "allow-inbound-ping" ],
      var.security_groups_map[ "allow-inbound-ssh" ],
      var.security_groups_map[ "allow-inbound-dns-dhcp" ]
    ]
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
  name   = "network-server"
  target = ibm_is_instance.network_server.primary_network_interface[ 0 ].id
}

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

data "ibm_is_security_group" "serve_http_https" {
  name = "serve_http_https"
}

resource "ibm_is_instance" "installation_server" {
  tags           = null
  resource_group = data.ibm_is_vpc.vpc.resource_group
  depends_on     = [ ibm_is_security_group.installation_server ]

  name       = "installation-server"
  image      = data.ibm_is_image.ubuntu_1804.id
  profile    = "bx2-2x8"
  primary_network_interface {
    name     = "eth0"
    subnet   = data.ibm_is_subnet.subnet_1.id
    security_groups = [ data.ibm_is_security_group.serve_http_https.id ]
  }
  vpc        = data.ibm_is_vpc.vpc.id
  zone       = data.ibm_is_subnet.subnet_1.zone
  keys       = [ data.ibm_is_ssh_key.admin_public_key.id ]
  user_data  = <<-EOT
    #cloud-config
    runcmd:
      - git clone https://github.com/j4zzcat/j4zzcat-ibmcloud.git /usr/local/src/j4zzcat-ibmcloud
      - bash /usr/local/src/j4zzcat-ibmcloud/openshift/lib/modules/installation-server/post-provision.sh

    power_state:
      mode: reboot
      timeout: 1
      condition: True
    EOT
}

resource "ibm_is_floating_ip" "installation_server" {
  tags           = null
  resource_group = data.ibm_is_vpc.vpc.resource_group
  depends_on     = [ ibm_is_instance.installation_server ]

  name   = "installation-server"
  target = ibm_is_instance.installation_server.primary_network_interface[ 0 ].id

}

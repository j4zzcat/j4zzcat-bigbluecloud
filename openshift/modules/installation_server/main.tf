data "ibm_is_vpc" "vpc" {
  name = var.vpc_name
}

# --- allow inbound TCP 7080 ---
resource "ibm_is_security_group" "allow_inbound_tcp_7080" {
  resource_group = var.resource_group_id

  name = "allow-inbound-tcp-7080"
  vpc  = data.ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "tcp_7080_rule" {
  group      = ibm_is_security_group.allow_inbound_tcp_7080.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 7080
    port_max = 7080
  }
}

module "installation-server" {
  source = "../../../terraform/modules/server"

  name              = "installation-server"
  vpc_name          = var.vpc_name
  subnet_id         = var.subnet_id
  key_id            = var.key_id
  resource_group_id = var.resource_group_id

  security_groups  = [
    var.standard_security_groups[ "allow_outbound_any" ],
    var.standard_security_groups[ "allow_inbound_ping" ],
    var.standard_security_groups[ "allow_inbound_ssh" ],
    var.standard_security_groups[ "allow_inbound_http_https" ],
    ibm_is_security_group.allow_inbound_tcp_7080.id
  ]

  user_data = <<EOT
#cloud-config
runcmd:
- timeout 1m bash -c 'while :; do ping -c 1 github.com && break; done'
- git clone https://github.com/j4zzcat/j4zzcat-ibmcloud.git /usr/local/src/j4zzcat-ibmcloud
- bash /usr/local/src/j4zzcat-ibmcloud/openshift/modules/installation_server/post_provision.sh
power_state:
mode: reboot
timeout: 1
condition: True
EOT
}

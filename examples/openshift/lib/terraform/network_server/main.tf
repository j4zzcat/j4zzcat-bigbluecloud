data "ibm_is_vpc" "vpc" {
  name = var.vpc_name
}

module "network_server" {
  source = "../../../../../lib/terraform/server"

  name              = var.name
  profile           = var.profile
  vpc_name          = var.vpc_name
  subnet_id         = var.subnet_id
  keys              = var.keys
  resource_group_id = var.resource_group_id

  security_groups  = [
    var.security_groups[ "allow_basic_operation" ],
    var.security_groups[ "allow_inbound_dns" ],
    var.security_groups[ "allow_inbound_sinatra" ]
  ]

  user_data = <<EOT
#cloud-config
runcmd:
  - timeout 1m bash -c 'while :; do ping -c 1 github.com && break; done'
  - git clone https://github.com/j4zzcat/j4zzcat-ibmcloud.git /usr/local/src/j4zzcat-ibmcloud
  - ln -s /usr/local/src/j4zzcat-ibmcloud /j4zzcat
  - bash /j4zzcat/lib/scripts/ubuntu_18/upgrade_os.sh
  - bash /j4zzcat/lib/scripts/ubuntu_18/install_basics.sh
  - bash /j4zzcat/lib/scripts/ubuntu_18/install_sinatra.sh
  - bash /j4zzcat/lib/scripts/ubuntu_18/install_dnsmasq.sh
power_state:
  mode: reboot
  timeout: 1
  condition: True
EOT
}

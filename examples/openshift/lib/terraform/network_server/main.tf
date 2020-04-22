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
}

resource "null_resource" "network_server_post_provision" {
  connection {
    type        = "ssh"
    user        = "root"
    private_key = file( var.keys[ 0 ] )
    host        = module.network_server.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "git clone https://github.com/j4zzcat/j4zzcat-ibmcloud.git /usr/local/src/j4zzcat-ibmcloud",
      "bash /usr/local/src/j4zzcat-ibmcloud/lib/scripts/ubuntu_18/upgrade_os.sh",
      "bash /usr/local/src/j4zzcat-ibmcloud/lib/scripts/ubuntu_18/install_dnsmasq.sh",
      "reboot"
    ]
  }
}

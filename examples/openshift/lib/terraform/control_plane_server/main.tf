data "ibm_is_vpc" "vpc" {
  name = var.vpc_name
}

module "bootstrap_server" {
  source = "../../../../../lib/terraform/server"

  name              = var.name
  profile           = var.profile
  vpc_name          = var.vpc_name
  subnet_id         = var.vpc.default_subnet
  keys              = var.keys
  security_groups   = var.security_groups 
  resource_group_id = var.resource_group_id
}

resource "null_resource" "bootstrap_server_post_provision" {
  connection {
    type        = "ssh"
    user        = "root"
    private_key = file( var.keys[ 0 ] )
    host        = module.bootstrap_server.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "git clone https://github.com/j4zzcat/j4zzcat-ibmcloud.git /usr/local/src/j4zzcat-ibmcloud",
      "bash /usr/local/src/j4zzcat-ibmcloud/lib/scripts/ubuntu_18/upgrade_os.sh",
      "bash /usr/local/src/j4zzcat-ibmcloud/lib/scripts/ubuntu_18/install_ipxe.sh",
      "bash /usr/local/src/j4zzcat-ibmcloud/lib/scripts/ubuntu_18/install_sinatra.sh",
      "bash /usr/local/src/j4zzcat-ibmcloud/examples/openshift/lib/scripts/openshift/install_client.sh",
      "bash /usr/local/src/j4zzcat-ibmcloud/examples/openshift/lib/scripts/openshift/generate_config.sh",
      "reboot"
    ]
  }
}

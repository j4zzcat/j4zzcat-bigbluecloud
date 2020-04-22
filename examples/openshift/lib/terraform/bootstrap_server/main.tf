data "ibm_is_vpc" "vpc" {
  name = var.vpc_name
}

module "bootstrap_server" {
  source = "../../../../../lib/terraform/server"

  name              = var.name
  profile           = var.profile
  vpc_name          = var.vpc_name
  subnet_id         = var.subnet_id
  keys              = var.keys
  resource_group_id = var.resource_group_id

  security_groups  = [
    var.security_groups[ "allow_basic_operation" ],
    var.security_groups[ "allow_inbound_http_https" ],
    var.security_groups[ "allow_inbound_sinatra" ],
    var.security_groups[ "allow_inbound_openshift_bootstrap" ]
  ]

  user_data = <<-EOT
    #cloud-init
    runcmd:
      - mkdir -p /usr/local/src/scripts
  EOT
}

resource "null_resource" "bootstrap_server_config" {
  provisioner "file" {
    source      = "${path.module.bootstrap_server}/../../scripts/ubuntu_18"
    destination = "/usr/local/src/scripts"

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file( var.keys[ 0 ] )
      host        = module.bootstrap_server.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "bash -c 'for script in upgrade_os install_basics install_ipxe install_sinatra; do bash /usr/local/src/${script}.sh; done; reboot'"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file( var.admin_key )
      host        = module.bootstrap_server.public_ip
    }
  }
}

#   user_data = join( "\n", [
#     "#cloud-config", "runcmd:",
#     "-", file( "${path.module}/../../scripts/ubuntu_18/upgrade_os.sh" ),
#     "-", file( "${path.module}/../../scripts/ubuntu_18/install_basics.sh" ),
#     "-", file( "${path.module}/../../scripts/ubuntu_18/install_sinatra.sh" ),
#     "-", templatefile( "${path.module}/../../scripts/ubuntu_18/config_resolve.sh", { domain_name = var.domain_name, nameserver_ip = var.nameserver_ip } ),
#     "-", file( "${path.module}/../../scripts/openshift/install_client.sh" ),
#     "-", file( "${path.module}/../../scripts/openshift/generate_config.sh" ),
#     "power_state:\nmode: reboot\ntimeout: 1\ncondition: True" ] )
# }

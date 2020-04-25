locals {
  bastion_key_file_private = file( var.bastion_key[ "private" ] )
  bastion_key_file_public  = file( var.bastion_key[ "public" ] )
}

resource "ibm_is_subnet" "bastion_subnet" {
  count          = var.bastion ? 1 : 0

  name           = "bastion-subnet"
  vpc            = ibm_is_vpc.vpc.id
  zone           = var.zone_name
  public_gateway = ibm_is_public_gateway.public_gateway.id
  total_ipv4_address_count = "256"
}

data "ibm_is_image" "ubuntu_1804" {
  name = "ibm-ubuntu-18-04-64"
}

resource "ibm_is_ssh_key" "bastion_key" {
  name           = "${ibm_is_vpc.vpc.name}-bastion-key"
  public_key     = local.bastion_key_file_public
  resource_group = var.resource_group_id

  provisioner "local-exec" {
    command = "ssh-keygen -t rsa -b 4096 -N '' -f ./keys/internal-key.rsa"
  }
}

resource "ibm_is_ssh_key" "internal_key" {
  name           = "${ibm_is_vpc.vpc.name}-internal-key"
  public_key     = "./keys/internl-key.rsa.pub"
  resource_group = var.resource_group_id
}

module "bastion_server" {
  source = "github.com/j4zzcat/j4zzcat-ibmcloud/lib/terraform/server"

  name              = "${ibm_is_vpc.name}-bastion-server"
  profile           = "bx2-2x8"
  vpc_name          = ibm_is_vpc.name
  subnet_id         = ibm_is_subnet.bastion_subnet.id
  fip               = true
  keys              = [ ibm_is_ssh_key.bastion_key.id ]
  resource_group_id = data.ibm_resource_group.resource_group.id
  security_groups   = [ local.security_groups[ "allow_basic_operation" ],
                        local.security_groups[ "allow_inbound_ssh" ] ]
  post_provision = {
    ssh_key      = file( local.bastion_key_file_private ),
    remote_exec  = [
      "git clone https://github.com/j4zzcat/j4zzcat-ibmcloud.git /usr/local/src/j4zzcat-ibmcloud",
      "bash /usr/local/src/j4zzcat-ibmcloud/lib/scripts/ubuntu_18/upgrade_os.sh",
      "bash /usr/local/src/j4zzcat-ibmcloud/lib/scripts/ubuntu_18/install_ibmcloud_cli.sh" ]
  }
}

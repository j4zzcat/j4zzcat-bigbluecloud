data "ibm_is_vpc" "vpc" {
  name = var.vpc_name
}

module "master_server" {
  source = "../../../../../lib/terraform/server"

  name              = var.name
  vpc_name          = var.vpc_name
  subnet_id         = var.subnet_id
  key_id            = var.key_id
  resource_group_id = var.resource_group_id

  security_groups  = [
    var.security_groups[ "allow_outbound_any" ],
    var.security_groups[ "allow_inbound_ping" ],
    var.security_groups[ "allow_inbound_ssh" ],
    var.security_groups[ "allow_inbound_openshift_bootstrap" ],
    var.security_groups[ "allow_inbound_openshift_internode" ]
  ]
}

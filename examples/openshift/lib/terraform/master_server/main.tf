data "ibm_is_vpc" "vpc" {
  name = var.vpc_name
}

module "master_server" {
  source = "../../../../../lib/terraform/server"

  name              = var.name
  profile           = var.profile
  vpc_name          = var.vpc_name
  subnet_id         = var.subnet_id
  keys              = var.keys
  resource_group_id = var.resource_group_id

  security_groups  = [
    var.security_groups[ "allow_basic_operation" ],
    var.security_groups[ "allow_inbound_openshift_bootstrap" ],
    var.security_groups[ "allow_inbound_openshift_internode" ]
  ]
}

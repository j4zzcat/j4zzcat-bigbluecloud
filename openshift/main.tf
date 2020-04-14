variable resource_group_name {}
variable vpc_name            {}
variable region_name         {}
variable zone_name           {}
variable admin_public_key    {}

provider "ibm" {
  region     = var.region_name
  generation = 2
}

data "ibm_resource_group" "resource_group" {
  name = var.resource_group_name
}

module "vpc_instance" {
  source = "../terraform/modules/vpc"

  name              = var.vpc_name
  zone_name         = var.zone_name
  default_admin_key = var.admin_public_key
  resource_group_id = data.ibm_resource_group.resource_group.id
}

module "installation_server_instance" {
 source = "./modules/installation_server"

 vpc_name                 = var.vpc_name
 subnet_id                = module.vpc_instance.default_subnet.id
 resource_group_id        = data.ibm_resource_group.resource_group.id
 key_id                   = module.vpc_instance.default_admin_key.id
 standard_security_groups = module.vpc_instance.standard_security_groups
}

module "network_server_instance" {
 source = "./modules/network_server"

 vpc_name                 = var.vpc_name
 subnet_id                = module.vpc_instance.default_subnet.id
 resource_group_id        = data.ibm_resource_group.resource_group.id
 key_id                   = module.vpc_instance.default_admin_key.id
 standard_security_groups = module.vpc_instance.standard_security_groups
}

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

module "vpc" {
  source = "../terraform/modules/vpc"

  name              = var.vpc_name
  zone_name         = var.zone_name
  default_admin_key = var.admin_public_key
  resource_group_id = data.ibm_resource_group.resource_group.id
}

module "openshift_security_groups" {
  source = "./modules/openshift_security_groups"
}

module "installation_server" {
 source = "./modules/installation_server"

 vpc_name                 = var.vpc_name
 subnet_id                = module.vpc.default_subnet.id
 resource_group_id        = data.ibm_resource_group.resource_group.id
 key_id                   = module.vpc.default_admin_key.id
 standard_security_groups = module.vpc.standard_security_groups
}

module "network_server" {
 source = "./modules/network_server"

 vpc_name                 = var.vpc_name
 subnet_id                = module.vpc.default_subnet.id
 resource_group_id        = data.ibm_resource_group.resource_group.id
 key_id                   = module.vpc.default_admin_key.id
 standard_security_groups = module.vpc.standard_security_groups
}

module "haproxy_masters" {
 source = "./modules/haproxy"

 name                     = "masters"
 vpc_name                 = var.vpc_name
 subnet_id                = module.vpc.default_subnet.id
 resource_group_id        = data.ibm_resource_group.resource_group.id
 key_id                   = module.vpc.default_admin_key.id
 standard_security_groups = module.vpc.standard_security_groups
}

module "haproxy_workers" {
 source = "./modules/haproxy_server"

 name                     = "workers"
 vpc_name                 = var.vpc_name
 subnet_id                = module.vpc.default_subnet.id
 resource_group_id        = data.ibm_resource_group.resource_group.id
 key_id                   = module.vpc.default_admin_key.id
 standard_security_groups = module.vpc.standard_security_groups
}

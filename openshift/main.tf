variable name                {}
variable region_name         {}
variable zone_name           {}
variable resource_group_name {}
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

  name              = var.name
  zone_name         = var.zone_name
  default_admin_key = var.admin_public_key
  resource_group_id = data.ibm_resource_group.resource_group.id
}

module "openshift_security_groups" {
  source            = "./modules/openshift_security_groups"
  vpc_name          = var.name
  resource_group_id = data.ibm_resource_group.resource_group.id
}

module "network_server" {
  source = "./modules/network_server"

  vpc_name                 = var.name
  subnet_id                = module.vpc.default_subnet.id
  resource_group_id        = data.ibm_resource_group.resource_group.id
  key_id                   = module.vpc.default_admin_key.id
  standard_security_groups = module.vpc.standard_security_groups
}

module "installation_server" {
 source = "./modules/installation_server"

 vpc_name                 = var.name
 subnet_id                = module.vpc.default_subnet.id
 resource_group_id        = data.ibm_resource_group.resource_group.id
 key_id                   = module.vpc.default_admin_key.id
 standard_security_groups = module.vpc.standard_security_groups
 nameserver               = module.network_server.private_ip
}

module "haproxy_masters" {
 source = "./modules/haproxy_server"

 name                      = "masters"
 vpc_name                  = var.name
 subnet_id                 = module.vpc.default_subnet.id
 resource_group_id         = data.ibm_resource_group.resource_group.id
 key_id                    = module.vpc.default_admin_key.id
 standard_security_groups  = module.vpc.standard_security_groups
 openshift_security_groups = module.openshift_security_groups.openshift_security_groups
 nameserver                = module.network_server.private_ip
}

# module "haproxy_workers" {
#  source = "./modules/haproxy_server"
#
#  name                     = "workers"
#  vpc_name                 = var.name
#  subnet_id                = module.vpc.default_subnet.id
#  resource_group_id        = data.ibm_resource_group.resource_group.id
#  key_id                   = module.vpc.default_admin_key.id
#  standard_security_groups = module.vpc.standard_security_groups
# }

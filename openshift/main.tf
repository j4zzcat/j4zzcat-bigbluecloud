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

module "security_groups" {
  source            = "./modules/security_groups"
  vpc_name          = var.name
  resource_group_id = data.ibm_resource_group.resource_group.id
}

module "network_server" {
  source = "./modules/network_server"

  name                     = "network-server"
  vpc_name                 = var.name
  subnet_id                = module.vpc.default_subnet.id
  resource_group_id        = data.ibm_resource_group.resource_group.id
  key_id                   = module.vpc.default_admin_key.id
  standard_security_groups = module.vpc.standard_security_groups
}

module "installation_server" {
 source = "./modules/installation_server"

 name                     = "installation-server"
 vpc_name                 = var.name
 subnet_id                = module.vpc.default_subnet.id
 resource_group_id        = data.ibm_resource_group.resource_group.id
 key_id                   = module.vpc.default_admin_key.id
 standard_security_groups = module.vpc.standard_security_groups
 nameserver               = module.network_server.private_ip
}

module "haproxy-masters" {
 source = "./modules/haproxy_server"

 name                      = "haproxy-masters"
 vpc_name                  = var.name
 subnet_id                 = module.vpc.default_subnet.id
 resource_group_id         = data.ibm_resource_group.resource_group.id
 key_id                    = module.vpc.default_admin_key.id
 standard_security_groups  = module.vpc.standard_security_groups
 openshift_security_groups = module.security_groups.openshift_security_groups
 nameserver                = module.network_server.private_ip
}

module "haproxy-workers" {
 source = "./modules/haproxy_server"

 name                      = "haproxy-workers"
 vpc_name                  = var.name
 subnet_id                 = module.vpc.default_subnet.id
 resource_group_id         = data.ibm_resource_group.resource_group.id
 key_id                    = module.vpc.default_admin_key.id
 standard_security_groups  = module.vpc.standard_security_groups
 openshift_security_groups = module.security_groups.openshift_security_groups
 nameserver                = module.network_server.private_ip
}

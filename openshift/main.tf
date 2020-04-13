variable resource_group_name {}
variable vpc_name            {}
variable region_name         {}
variable zone_name           {}
variable admin_public_key    {}

provider "ibm" {
  region     = var.region_name
  generation = 2
}

data "ibm_resource_group" "this_resource_group" {
  name = var.resource_group_name
}

module "vpc" {
  source = "../terraform/modules/vpc"

  name              = var.vpc_name
  zone_name         = var.zone_name
  resource_group_id = data.ibm_resource_group.this_resource_group.id
}

# module "installation-server" {
#   source = "./modules/installation-server"
#
#   vpc_id            = module.vpc.id
#   zone_name         = var.zone_name
#   subnet_id         = module.vpc.subnet_1.id
#   admin_public_key  = var.admin_public_key
#   resource_group_id = data.ibm_resource_group.this_resource_group.id
# }

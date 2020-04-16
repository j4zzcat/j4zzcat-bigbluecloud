variable name                {}
variable region_name         {}
variable zone_name           {}
variable resource_group_name {}
variable admin_key           {}

locals {
  admin_public_key = "${var.admin_key}.pub"
  domain           = var.name
}

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
  default_admin_key = local.admin_public_key
  resource_group_id = data.ibm_resource_group.resource_group.id
}

module "security_groups" {
  source            = "./modules/security_groups"
  vpc_name          = var.name
  resource_group_id = data.ibm_resource_group.resource_group.id
}

module "network_server" {
  source = "./modules/network_server"

  name              = "network-server"
  vpc_name          = var.name
  subnet_id         = module.vpc.default_subnet.id
  resource_group_id = data.ibm_resource_group.resource_group.id
  key_id            = module.vpc.default_admin_key.id
  security_groups   = merge( module.vpc.security_groups, module.security_groups.security_groups )
}

module "installation_server" {
  source = "./modules/installation_server"

  name              = "installation-server"
  vpc_name          = var.name
  subnet_id         = module.vpc.default_subnet.id
  resource_group_id = data.ibm_resource_group.resource_group.id
  key_id            = module.vpc.default_admin_key.id
  nameserver        = module.network_server.private_ip
  security_groups   = merge( module.vpc.security_groups, module.security_groups.security_groups )
}

module "haproxy_masters" {
  source = "./modules/haproxy_server"

  name              = "haproxy-masters"
  vpc_name          = var.name
  subnet_id         = module.vpc.default_subnet.id
  resource_group_id = data.ibm_resource_group.resource_group.id
  key_id            = module.vpc.default_admin_key.id
  nameserver        = module.network_server.private_ip
  security_groups   = merge( module.vpc.security_groups, module.security_groups.security_groups )
}

module "haproxy_workers" {
  source = "./modules/haproxy_server"

  name              = "haproxy-workers"
  vpc_name          = var.name
  subnet_id         = module.vpc.default_subnet.id
  resource_group_id = data.ibm_resource_group.resource_group.id
  key_id            = module.vpc.default_admin_key.id
  nameserver        = module.network_server.private_ip
  security_groups   = merge( module.vpc.security_groups, module.security_groups.security_groups )
}

resource "null_resource" "register_with_nameserver" {
  provisioner "local-exec" {
    command = <<EOT
        bash ./scripts/local_exec/register_with_nameserver.sh \
          ${var.admin_key} \
          ${module.network_server.public_ip} \
          ${local.domain} \
          network_server:${module.network_server.private_ip} \
          installation_server:${module.installation_server.private_ip} \
          haproxy_masters:${module.haproxy_masters.private_ip} \
          haproxy_workers:${module.haproxy_workers.private_ip}
EOT
  }
}

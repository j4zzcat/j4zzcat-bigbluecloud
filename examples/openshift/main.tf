variable cluster_name        {}
variable domain_name         {}
variable region_name         {}
variable zone_name           {}
variable resource_group_name {}
variable admin_key           {}

locals {
  admin_public_key = "${var.admin_key}.pub"
  vpc_name         = var.cluster_name
}

provider "ibm" {
  region     = var.region_name
  generation = 2
}

data "ibm_resource_group" "resource_group" {
  name = var.resource_group_name
}

module "vpc" {
  source = "../../lib/terraform/vpc"

  name              = local.vpc_name
  zone_name         = var.zone_name
  default_admin_key = local.admin_public_key
  resource_group_id = data.ibm_resource_group.resource_group.id
}

module "security_groups" {
  source            = "./lib/terraform/security_groups"
  vpc_name          = local.vpc_name
  resource_group_id = data.ibm_resource_group.resource_group.id
}

module "network_server" {
  source = "./lib/terraform/network_server"

  name              = "network-server"
  vpc_name          = local.vpc_name
  subnet_id         = module.vpc.default_subnet.id
  resource_group_id = data.ibm_resource_group.resource_group.id
  key_id            = module.vpc.default_admin_key.id
  security_groups   = merge( module.vpc.security_groups, module.security_groups.security_groups )
  cluster_name      = var.cluster_name
  domain_name       = var.domain_name
}

module "installation_server" {
  source = "./lib/terraform/installation_server"

  name              = "installation-server"
  vpc_name          = local.vpc_name
  subnet_id         = module.vpc.default_subnet.id
  resource_group_id = data.ibm_resource_group.resource_group.id
  key_id            = module.vpc.default_admin_key.id
  security_groups   = merge( module.vpc.security_groups, module.security_groups.security_groups )
  nameserver        = module.network_server.private_ip
  domain_name       = var.domain_name
}

module "haproxy_masters" {
  source = "./lib/terraform/haproxy_server"

  name              = "haproxy-masters"
  vpc_name          = local.vpc_name
  subnet_id         = module.vpc.default_subnet.id
  resource_group_id = data.ibm_resource_group.resource_group.id
  key_id            = module.vpc.default_admin_key.id
  security_groups   = merge( module.vpc.security_groups, module.security_groups.security_groups )
  nameserver        = module.network_server.private_ip
  domain_name       = var.domain_name
}

module "haproxy_workers" {
  source = "./lib/terraform/haproxy_server"

  name              = "haproxy-workers"
  vpc_name          = local.vpc_name
  subnet_id         = module.vpc.default_subnet.id
  resource_group_id = data.ibm_resource_group.resource_group.id
  key_id            = module.vpc.default_admin_key.id
  security_groups   = merge( module.vpc.security_groups, module.security_groups.security_groups )
  nameserver        = module.network_server.private_ip
  domain_name       = var.domain_name
}

module "master_1" {
  source = "./lib/terraform/master_server"

  name              = "master-1"
  vpc_name          = local.vpc_name
  subnet_id         = module.vpc.default_subnet.id
  resource_group_id = data.ibm_resource_group.resource_group.id
  key_id            = module.vpc.default_admin_key.id
  security_groups   = merge( module.vpc.security_groups, module.security_groups.security_groups )
}

module "master_2" {
  source = "./lib/terraform/master_server"

  name              = "master-2"
  vpc_name          = local.vpc_name
  subnet_id         = module.vpc.default_subnet.id
  resource_group_id = data.ibm_resource_group.resource_group.id
  key_id            = module.vpc.default_admin_key.id
  security_groups   = merge( module.vpc.security_groups, module.security_groups.security_groups )
}

module "master_3" {
  source = "./lib/terraform/master_server"

  name              = "master-3"
  vpc_name          = local.vpc_name
  subnet_id         = module.vpc.default_subnet.id
  resource_group_id = data.ibm_resource_group.resource_group.id
  key_id            = module.vpc.default_admin_key.id
  security_groups   = merge( module.vpc.security_groups, module.security_groups.security_groups )
}

resource "null_resource" "register_with_nameserver" {
  provisioner "local-exec" {
    command = <<EOT
      bash ./lib/scripts/local_exec/nameserver_add_host_records.sh \
        ${var.admin_key} ${module.network_server.public_ip} \
        ${var.cluster_name} ${var.domain_name} \
        network-server:${module.network_server.private_ip} \
        installation-server:${module.installation_server.private_ip} \
        haproxy-masters:${module.haproxy_masters.private_ip} \
        haproxy-workers:${module.haproxy_workers.private_ip} \
        master-1:${module.master_1.private_ip} \
        master-2:${module.master_2.private_ip} \
        master-3:${module.master_3.private_ip}
EOT
  }

  provisioner "local-exec" {
    command = <<EOT
      bash ./lib/scripts/local_exec/nameserver_add_cluster_records.sh \
        ${var.admin_key} ${module.network_server.public_ip} \
        ${var.cluster_name} ${var.domain_name} \
        ${module.haproxy_masters.private_ip} \
        ${module.haproxy_workers.private_ip} \
        ${module.master_1.private_ip} \
        ${module.master_2.private_ip} \
        ${module.master_3.private_ip}
EOT
  }

}

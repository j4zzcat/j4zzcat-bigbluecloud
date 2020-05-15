####
# DNS Records
#

locals {
  bastion_fip       = module.vpc.bastion_fip
  installer_pip     = ibm_is_instance.installer.primary_network_interface[ 0 ].primary_ipv4_address
  load_balancer_pip = ibm_is_instance.load_balancer.primary_network_interface[ 0 ].primary_ipv4_address
  nat_server_fip    = ibm_compute_vm_instance.nat_server.ipv4_address
  nat_server_pip    = ibm_compute_vm_instance.nat_server.ipv4_address_private
  bootstrap_pip     = ibm_compute_vm_instance.bootstrap.ipv4_address_private
  master_1_pip      = ibm_compute_vm_instance.master[ 0 ].ipv4_address_private
  master_2_pip      = ibm_compute_vm_instance.master[ 1 ].ipv4_address_private
  master_3_pip      = ibm_compute_vm_instance.master[ 2 ].ipv4_address_private
  worker_1_pip      = ibm_compute_vm_instance.worker[ 0 ].ipv4_address_private
  worker_2_pip      = ibm_compute_vm_instance.worker[ 1 ].ipv4_address_private

  hostname_records = {
    "installer"     = local.installer_pip,
    "load-balancer" = local.load_balancer_pip,
    "nat-server"    = local.nat_server_pip
    "bootstrap"     = local.bootstrap_pip,
    "master-1"      = local.master_1_pip,
    "master-2"      = local.master_2_pip,
    "master-3"      = local.master_3_pip,
    "worker-1"      = local.worker_1_pip,
    "worker-2"      = local.worker_2_pip
  }

  alias_records = {
    "api"     = "load-balancer.${var.cluster_name}.${var.domain_name}",
    "api-int" = "load-balancer.${var.cluster_name}.${var.domain_name}",
    "*.apps"  = "load-balancer.${var.cluster_name}.${var.domain_name}",
    "etcd-0"  = "master-1.${var.cluster_name}.${var.domain_name}",
    "etcd-1"  = "master-2.${var.cluster_name}.${var.domain_name}",
    "etcd-2"  = "master-3.${var.cluster_name}.${var.domain_name}"
  }
}

####
# Hosts file
#

resource "null_resource" "rm_hosts_file" {
  provisioner "local-exec" {
    command = <<-EOT
      rm -f ${local.config_hosts_file}
    EOT
  }
}

resource "local_file" "create_hosts_file" {
  filename        = local.config_hosts_file
  file_permission = "0644"
  content = <<-EOT
    bastion_fip       = ${local.bastion_fip}
    installer_pip     = ${local.installer_pip}
    load_balancer_pip = ${local.load_balancer_pip}
    nat_server_fip    = ${local.nat_server_fip}
    nat_server_pip    = ${local.nat_server_pip}
    bootstrap_pip     = ${local.bootstrap_pip}
    master_1_pip      = ${local.master_1_pip}
    master_2_pip      = ${local.master_2_pip}
    master_3_pip      = ${local.master_3_pip}
    worker_1_pip      = ${local.worker_1_pip}
    worker_2_pip      = ${local.worker_2_pip}
  EOT
}

####
# VPC DNS
#

resource "ibm_resource_instance" "dns_service" {
  name              = "${var.cluster_name}-${var.domain_name}"
  service           = "dns-svcs"
  plan              = "standard-dns"
  location          = "global"
  resource_group_id = data.ibm_resource_group.resource_group.id
}

resource "ibm_dns_zone" "vpc" {
  name        = "${var.cluster_name}.${var.domain_name}"
  instance_id = ibm_resource_instance.dns_service.guid
}

resource "ibm_dns_permitted_network" "vpc" {
  instance_id = ibm_resource_instance.dns_service.guid
  zone_id     = ibm_dns_zone.vpc.zone_id
  vpc_crn     = module.vpc.crn
  type        = "vpc"
}

resource "ibm_dns_resource_record" "hostname_records" {
  count = length( local.hostname_records )

  instance_id = ibm_resource_instance.dns_service.guid
  zone_id     = ibm_dns_zone.vpc.zone_id
  type        = "A"
  name        = keys( local.hostname_records )[ count.index ]
  rdata       = values( local.hostname_records )[ count.index ]
  ttl         = 3600
}

resource "ibm_dns_resource_record" "alias_records" {
  count = length( local.alias_records )

  instance_id = ibm_resource_instance.dns_service.guid
  zone_id     = ibm_dns_zone.vpc.zone_id
  type        = "CNAME"
  name        = keys( local.alias_records )[ count.index ]
  rdata       = values( local.alias_records )[ count.index ]
  ttl         = 3600
}

resource "ibm_dns_resource_record" "srv_records" {
  count = 3

  instance_id = ibm_resource_instance.dns_service.guid
  zone_id     = ibm_dns_zone.vpc.zone_id
  type        = "SRV"
  name        = "${var.cluster_name}.${var.domain_name}"
  rdata       = "etcd-${count.index}.${var.cluster_name}.${var.domain_name}"
  priority    = 0
  weight      = 10
  port        = 2380
  service     = "_etcd-server-ssl"
  protocol    = "tcp"
  ttl         = 43200
}

####
# IAAS DNS
#

resource "ibm_dns_domain" "dns_service" {
  name = "${var.cluster_name}.${var.domain_name}"
}

resource "ibm_dns_record" "hostname_records" {
  count = length( local.alias_records )

  domain_id = ibm_dns_domain.dns_service.id
  type      = "a"
  host      = keys( local.hostname_records )[ count.index ]
  data      = values( local.hostname_records )[ count.index ]
  ttl       = 3600
}

resource "ibm_dns_record" "alias_records" {
  count = length( local.alias_records )

  domain_id = ibm_dns_domain.dns_service.id
  type      = "cname"
  host      = keys( local.alias_records )[ count.index ]
  data      = "${values( local.alias_records )[ count.index ]}."
  ttl       = 3600
}

resource "ibm_dns_record" "srv_records" {
  count = 3

  domain_id = ibm_dns_domain.dns_service.id
  type      = "srv"
  data      = "etcd-${count.index}.${var.cluster_name}.${var.domain_name}"
  host      = "${var.cluster_name}.${var.domain_name}"
  ttl       = 43200
  port      = 2380
  priority  = 0
  protocol  = "_tcp"
  weight    = 10
  service   = "_etcd-server-ssl"
}

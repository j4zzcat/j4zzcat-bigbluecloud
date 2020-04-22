variable cluster_name        {}
variable domain_name         {}
variable region_name         {}
variable zone_name           {}
variable resource_group_name {}
variable pull_secret         {}

provider "ibm" {
  region     = var.region_name
  generation = 2
}

data "ibm_resource_group" "resource_group" {
  name = var.resource_group_name
}

locals {
  vpc_name = var.cluster_name
}

module "vpc" {
  source = "../../lib/terraform/j4zzcat_vpc"

  name              = local.vpc_name
  zone_name         = var.zone_name
  resource_group_id = data.ibm_resource_group.resource_group.id
}

module "security_groups" {
  source            = "./lib/terraform/security_groups"

  vpc_name          = local.vpc_name
  resource_group_id = data.ibm_resource_group.resource_group.id
}

module "ssh_key" {
  source = "../../lib/terraform/j4zzcat_ssh_key"

  keys              = [ "admin_key", "bastion_key" ]
  resource_group_id = data.ibm_resource_group.resource_group.id
}

locals {
  security_groups = merge( module.security_groups.security_groups,
                           module.vpc.security_groups )
}

# module "network_server" {
#   source = "./lib/terraform/network_server"
#
#   name              = "network-server"
#   profile           = var.infra_profile
#   vpc_name          = local.vpc_name
#   subnet_id         = module.vpc.default_subnet.id
#   keys              = module.ssh_keys.ids
#   security_groups   = merge( module.vpc.security_groups, module.security_groups.security_groups )
#   resource_group_id = data.ibm_resource_group.resource_group.id
# }

module "bootstrap_server" {
  source = "../../lib/terraform/j4zzcat_server"

  name              = "bootstrap-server"
  profile           = "bx2-2x8"
  vpc_name          = local.vpc_name
  subnet_id         = module.vpc.default_subnet.id
  keys              = module.ssh_key.ids
  security_groups   = [ local.security_groups[ "allow_basic_operation" ],
                        local.security_groups[ "allow_inbound_http_https" ],
                        local.security_groups[ "allow_inbound_sinatra" ],
                        local.security_groups[ "allow_inbound_openshift_bootstrap" ] ]
  resource_group_id = data.ibm_resource_group.resource_group.id
  post_provision    = [
    "git clone https://github.com/j4zzcat/j4zzcat-ibmcloud.git /usr/local/src/j4zzcat-ibmcloud",
    "bash /usr/local/src/j4zzcat-ibmcloud/lib/scripts/ubuntu_18/upgrade_os.sh",
    "bash /usr/local/src/j4zzcat-ibmcloud/lib/scripts/ubuntu_18/install_ipxe.sh",
    "bash /usr/local/src/j4zzcat-ibmcloud/lib/scripts/ubuntu_18/install_sinatra.sh",
    "bash /usr/local/src/j4zzcat-ibmcloud/examples/openshift/lib/scripts/openshift/install_client.sh",
    "bash /usr/local/src/j4zzcat-ibmcloud/examples/openshift/lib/scripts/openshift/generate_config.sh",
    "reboot"
  ]
  # nameserver_ip     = module.network_server.private_ip
}

# module "haproxy_server" {
#   source = "./lib/terraform/haproxy_server"
#
#   name              = "haproxy-server"
#   profile           = var.infra_profile
#   vpc_name          = local.vpc_name
#   subnet_id         = module.vpc.default_subnet.id
#   resource_group_id = data.ibm_resource_group.resource_group.id
#   keys              = [ module.vpc.default_admin_key.id ]
#   security_groups   = merge( module.vpc.security_groups, module.security_groups.security_groups )
#   nameserver        = module.network_server.private_ip
#   domain_name       = var.domain_name
# }
#
# module "master_1" {
#   source = "./lib/terraform/master_server"
#
#   name              = "master-1"
#   profile           = var.masters_profile
#   vpc_name          = local.vpc_name
#   subnet_id         = module.vpc.default_subnet.id
#   resource_group_id = data.ibm_resource_group.resource_group.id
#   keys              = [ module.vpc.default_admin_key.id ]
#   security_groups   = merge( module.vpc.security_groups, module.security_groups.security_groups )
# }
#
# module "master_2" {
#   source = "./lib/terraform/master_server"
#
#   name              = "master-2"
#   profile           = var.masters_profile
#   vpc_name          = local.vpc_name
#   subnet_id         = module.vpc.default_subnet.id
#   resource_group_id = data.ibm_resource_group.resource_group.id
#   keys              = [ module.vpc.default_admin_key.id ]
#   security_groups   = merge( module.vpc.security_groups, module.security_groups.security_groups )
# }
#
# module "master_3" {
#   source = "./lib/terraform/master_server"
#
#   name              = "master-3"
#   profile           = var.masters_profile
#   vpc_name          = local.vpc_name
#   subnet_id         = module.vpc.default_subnet.id
#   resource_group_id = data.ibm_resource_group.resource_group.id
#   keys              = [ module.vpc.default_admin_key.id ]
#   security_groups   = merge( module.vpc.security_groups, module.security_groups.security_groups )
# }
#
# module "worker_1" {
#   source = "./lib/terraform/worker_server"
#
#   name              = "worker-1"
#   profile           = var.workers_profile
#   vpc_name          = local.vpc_name
#   subnet_id         = module.vpc.default_subnet.id
#   resource_group_id = data.ibm_resource_group.resource_group.id
#   keys              = [ module.vpc.default_admin_key.id ]
#   security_groups   = merge( module.vpc.security_groups, module.security_groups.security_groups )
# }
#
# module "worker_2" {
#   source = "./lib/terraform/worker_server"
#
#   name              = "worker-2"
#   profile           = var.workers_profile
#   vpc_name          = local.vpc_name
#   subnet_id         = module.vpc.default_subnet.id
#   resource_group_id = data.ibm_resource_group.resource_group.id
#   keys              = [ module.vpc.default_admin_key.id ]
#   security_groups   = merge( module.vpc.security_groups, module.security_groups.security_groups )
# }
#
# resource "null_resource" "network_server_post_provision" {
#   connection {
#     type        = "ssh"
#     user        = "root"
#     private_key = file( var.admin_key )
#     host        = module.network_server.public_ip
#   }
#
#   provisioner "remote-exec" {
#     inline = [
#       "cloud-init status --wait"
#     ]
#   }
#
#   provisioner "file" {
#     source      = var.pull_secret
#     destination = "/etc/dnsmasq.conf"
#
#     content = <<-EOT
#       port=53
#       no-hosts
#       addn-hosts=/etc/dnsmasq.hosts
#       log-queries
#       domain-needed
#       bogus-priv
#       expand-hosts
#       local=/${var.cluster_name}.${var.domain_name}/
#       domain=${var.cluster_name}.${var.domain_name}
#
#       host-record=api.${var.cluster_name}.${var.domain_name}.,${module.haproxy_server.private_ip}
#       host-record=api-int.${var.cluster_name}.${var.domain_name}.,${module.haproxy_server.private_ip}
#       host-record=*.apps.${var.cluster_name}.${var.domain_name}.,${module.haproxy_server.private_ip}
#       host-record=etcd-0.${var.cluster_name}.${var.domain_name}.,${module.master_1.private_ip}
#       host-record=etcd-1.${var.cluster_name}.${var.domain_name}.,${module.master_2.private_ip}
#       host-record=etcd-2.${var.cluster_name}.${var.domain_name}.,${module.master_3.private_ip}
#       srv-host=_etcd-server-ssl._tcp.${var.cluster_name}.${var.domain_name}.,etcd-0.${var.cluster_name}.${var.domain_name},2380,0,10
#       srv-host=_etcd-server-ssl._tcp.${var.cluster_name}.${var.domain_name}.,etcd-1.${var.cluster_name}.${var.domain_name},2380,0,10
#       srv-host=_etcd-server-ssl._tcp.${var.cluster_name}.${var.domain_name}.,etcd-2.${var.cluster_name}.${var.domain_name},2380,0,10
#     EOT
#   }
#
#   provisioner "file" {
#     source      = var.pull_secret
#     destination = "/etc/dnsmasq.hosts"
#
#     content = <<-EOT
#       ${module.bootstrap_server.private_ip} ${module.bootstrap_server.name}.${var.cluster_name}.${var.domain_name}
#       ${module.network_server.private_ip} ${module.network_server.name}.${var.cluster_name}.${var.domain_name}
#       ${module.haproxy_server.private_ip} ${module.haproxy_server.name}.${var.cluster_name}.${var.domain_name}
#       ${module.master_1.private_ip} ${module.master_1.name}.${var.cluster_name}.${var.domain_name}
#       ${module.master_2.private_ip} ${module.master_2.name}.${var.cluster_name}.${var.domain_name}
#       ${module.master_3.private_ip} ${module.master_3.name}.${var.cluster_name}.${var.domain_name}
#       ${module.worker_1.private_ip} ${module.worker_1.name}.${var.cluster_name}.${var.domain_name}
#       ${module.worker_2.private_ip} ${module.worker_2.name}.${var.cluster_name}.${var.domain_name}
#     EOT
#   }
#
#   provisioner "remote-exec" {
#     inline = [
#       "systemctl restart dnsmasq"
#     ]
#   }
# }
#
# resource "null_resource" "haproxy_server_post_provision" {
#   connection {
#     type        = "ssh"
#     user        = "root"
#     private_key = file( var.admin_key )
#     host        = module.haproxy_server.public_ip
#   }
#
#   provisioner "file" {
#     source      = var.pull_secret
#     destination = "/opt/openshift/pull_secret.txt"
#
#     content = <<-EOT
#       global
#         log 127.0.0.1 local2
#         chroot /var/lib/haproxy
#         pidfile /var/run/haproxy.pid
#         maxconn 4000
#         user haproxy
#         group haproxy
#         daemon
#         stats socket /var/lib/haproxy/stats
#         ssl-default-bind-ciphers PROFILE=SYSTEM
#         ssl-default-server-ciphers PROFILE=SYSTEM
#
#       defaults
#         mode http
#         log global
#         option httplog
#         option dontlognull
#         option http-server-close
#         option forwardfor except 127.0.0.0/8
#         option redispatch
#         retries 3
#         timeout http-request 10s
#         timeout queue 1m
#         timeout connect 10s
#         timeout client 1m
#         timeout server 1m
#         timeout http-keep-alive 10s
#         timeout check 10s
#         maxconn 3000
#
#       frontend masters_api
#         mode tcp
#         option tcplog
#         bind api.${var.cluster_name}.${var.domain_name}:6443
#         default_backend masters_api
#
#       frontend masters_machine_config
#         mode tcp
#         option tcplog
#         bind api.${var.cluster_name}.${var.domain_name}:22623
#         default_backend masters_machine_config
#
#       frontend router_http
#         mode tcp
#         option tcplog
#         bind apps.${var.cluster_name}.${var.domain_name}:80
#         default_backend router_http
#
#       frontend router_https
#         mode tcp
#         option tcplog
#         bind apps.${var.cluster_name}.${var.domain_name}:443
#         default_backend router_https
#
#       backend masters_api
#         mode tcp
#         balance source
#         server bootstrap-server.${var.cluster_name}.${var.domain_name}:6443 check
#         server ${module.master_1.name}.${var.cluster_name}.${var.domain_name}:6443 check
#         server ${module.master_2.name}.${var.cluster_name}.${var.domain_name}:6443 check
#         server ${module.master_3.name}.${var.cluster_name}.${var.domain_name}:6443 check
#
#       backend masters_machine_config
#         mode tcp
#         balance source
#         server bootstrap-server.${var.cluster_name}.${var.domain_name}:22623 check
#         server ${module.master_1.name}.${var.cluster_name}.${var.domain_name}:22623 check
#         server ${module.master_2.name}.${var.cluster_name}.${var.domain_name}:22623 check
#         server ${module.master_3.name}.${var.cluster_name}.${var.domain_name}:22623 check
#
#       backend router_http
#         mode tcp
#         server ${module.worker_1.name}.${var.cluster_name}.${var.domain_name}:80 check
#         server ${module.worker_2.name}.${var.cluster_name}.${var.domain_name}:80 check
#
#       backend router_https
#         mode tcp
#         server ${module.worker_1.name}.${var.cluster_name}.${var.domain_name}:443 check
#         server ${module.worker_2.name}.${var.cluster_name}.${var.domain_name}:443 check
#     EOT
#   }
# }
#
# resource "null_resource" "bootstrap_server_post_provision" {
#   connection {
#      type        = "ssh"
#      user        = "root"
#      private_key = file( var.admin_key )
#      host        = module.bootstrap_server.public_ip
#    }
#
#   provisioner "file" {
#      source      = var.pull_secret
#      destination = "/opt/openshift/pull_secret.txt"
#    }
# }

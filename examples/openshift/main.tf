variable cluster_name        {}
variable domain_name         {}
variable region_name         {}
variable zone_name           {}
variable resource_group_name {}
variable bastion_key         {}
variable cluster_key         {}
variable pull_secret         {}

locals {
  vpc_name      = var.cluster_name
  repo_home     = "https://github.com/j4zzcat/j4zzcat-ibmcloud"
  repo_home_raw = "https://raw.githubusercontent.com/j4zzcat/j4zzcat-ibmcloud/master"
  vpc_key       = var.cluster_key
  iaas_key      = var.cluster_key
  hosts_file    = "./hosts"
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

  name                = local.vpc_name
  zone_name           = var.zone_name
  classic_access      = true
  bastion             = true
  bastion_key         = var.bastion_key
  resource_group_id   = data.ibm_resource_group.resource_group.id
}

####
# VPC SSH Key
#

resource "ibm_is_ssh_key" "vpc_key" {
  name           = "${local.vpc_name}-cluster-key"
  public_key     = file( "${local.vpc_key}.pub" )
  resource_group = data.ibm_resource_group.resource_group.id
}

###
# Provision the control plane
#

resource "ibm_is_instance" "cp_master" {
  count = 3

  name           = "cp-master-${count.index + 1}"
  image          = data.ibm_is_image.ubuntu_1804.id
  profile        = "bx2-2x8"
  vpc            = module.vpc.id
  zone           = module.vpc.vpc_subnet.zone
  keys           = [ ibm_is_ssh_key.vpc_key.id ]
  resource_group = data.ibm_resource_group.resource_group.id

  primary_network_interface {
    name            = "eth0"
    subnet          = module.vpc.vpc_subnet.id
    security_groups = [ module.vpc.security_groups[ "vpc_default" ] ]
  }
}

resource "ibm_is_instance" "cp_worker" {
  count = 2

  name           = "cp-worker-${count.index + 1}"
  image          = data.ibm_is_image.ubuntu_1804.id
  profile        = "bx2-2x8"
  vpc            = module.vpc.id
  zone           = module.vpc.vpc_subnet.zone
  keys           = [ ibm_is_ssh_key.vpc_key.id ]
  resource_group = data.ibm_resource_group.resource_group.id

  primary_network_interface {
    name            = "eth0"
    subnet          = module.vpc.vpc_subnet.id
    security_groups = [ module.vpc.security_groups[ "vpc_default" ] ]
  }
}

####
# Provision the install-server
#

data "ibm_is_image" "ubuntu_1804" {
  name = "ibm-ubuntu-18-04-64"
}

resource "ibm_is_instance" "install_server" {
  name           = "install-server"
  image          = data.ibm_is_image.ubuntu_1804.id
  profile        = "bx2-2x8"
  vpc            = module.vpc.id
  zone           = module.vpc.vpc_subnet.zone
  keys           = [ ibm_is_ssh_key.vpc_key.id ]
  resource_group = data.ibm_resource_group.resource_group.id

  primary_network_interface {
    name            = "eth0"
    subnet          = module.vpc.vpc_subnet.id
    security_groups = [ module.vpc.security_groups[ "vpc_default" ] ]
  }

  connection {
    type                = "ssh"
    bastion_user        = "root"
    bastion_private_key = file( var.bastion_key )
    bastion_host        = module.vpc.bastion_fip
    host                = ibm_is_instance.install_server.primary_network_interface[ 0 ].primary_ipv4_address
    user                = "root"
    private_key         = file( local.vpc_key )
  }

  provisioner "remote-exec" {
    scripts = [
      "${path.module}/../../lib/scripts/ubuntu_18/upgrade_os.sh",
      "${path.module}/../../lib/scripts/ubuntu_18/install_sinatra.sh",
      "${path.module}/lib/scripts/openshift/install_client.sh",
      "${path.module}/../../lib/scripts/ubuntu_18/do_reboot.sh" ]
  }

  provisioner "file" {
    source      = var.pull_secret
    destination = "/opt/openshift/etc"
  }

  provisioner "file" {
    source      = "${path.module}/main.auto.tfvars"
    destination = "/opt/openshift/etc"
  }
}

resource "ibm_is_instance" "haproxy_server" {
  name           = "haproxy-server"
  image          = data.ibm_is_image.ubuntu_1804.id
  profile        = "bx2-2x8"
  vpc            = module.vpc.id
  zone           = module.vpc.vpc_subnet.zone
  keys           = [ ibm_is_ssh_key.vpc_key.id ]
  resource_group = data.ibm_resource_group.resource_group.id

  primary_network_interface {
    name            = "eth0"
    subnet          = module.vpc.vpc_subnet.id
    security_groups = [ module.vpc.security_groups[ "vpc_default" ] ]
  }

  connection {
    type                = "ssh"
    bastion_user        = "root"
    bastion_private_key = file( var.bastion_key )
    bastion_host        = module.vpc.bastion_fip
    host                = ibm_is_instance.haproxy_server.primary_network_interface[ 0 ].primary_ipv4_address
    user                = "root"
    private_key         = file( local.vpc_key )
  }

  provisioner "remote-exec" {
    scripts = [
      "${path.module}/../../lib/scripts/ubuntu_18/upgrade_os.sh",
      "${path.module}/../../lib/scripts/ubuntu_18/install_haproxy.sh" ]
  }

  provisioner "file" {
    destination = "/etc/haproxy.conf"

    content = <<-EOT
      global
        log 127.0.0.1 local2
        chroot /var/lib/haproxy
        pidfile /var/run/haproxy.pid
        maxconn 4000
        user haproxy
        group haproxy
        daemon
        stats socket /var/lib/haproxy/stats
        ssl-default-bind-ciphers PROFILE=SYSTEM
        ssl-default-server-ciphers PROFILE=SYSTEM

      defaults
        mode http
        log global
        option httplog
        option dontlognull
        option http-server-close
        option forwardfor except 127.0.0.0/8
        option redispatch
        retries 3
        timeout http-request 10s
        timeout queue 1m
        timeout connect 10s
        timeout client 1m
        timeout server 1m
        timeout http-keep-alive 10s
        timeout check 10s
        maxconn 3000

      frontend masters_api
        mode tcp
        option tcplog
        bind api.${var.cluster_name}.${var.domain_name}:6443
        default_backend masters_api

      frontend masters_machine_config
        mode tcp
        option tcplog
        bind api.${var.cluster_name}.${var.domain_name}:22623
        default_backend masters_machine_config

      frontend router_http
        mode tcp
        option tcplog
        bind apps.${var.cluster_name}.${var.domain_name}:80
        default_backend router_http

      frontend router_https
        mode tcp
        option tcplog
        bind apps.${var.cluster_name}.${var.domain_name}:443
        default_backend router_https

      backend masters_api
        mode tcp
        balance source
        server ${ibm_is_instance.install_server.name}.${var.cluster_name}.${var.domain_name}:6443 check
        server master-1.${var.cluster_name}.${var.domain_name}:6443 check
        server master-2.${var.cluster_name}.${var.domain_name}:6443 check
        server master-3.${var.cluster_name}.${var.domain_name}:6443 check

      backend masters_machine_config
        mode tcp
        balance source
        server ${ibm_is_instance.install_server.name}.${var.cluster_name}.${var.domain_name}:22623 check
        server ${ibm_is_instance.cp_master[ 0 ].name}.${var.cluster_name}.${var.domain_name}:22623 check
        server ${ibm_is_instance.cp_master[ 1 ].name}.${var.cluster_name}.${var.domain_name}:22623 check
        server ${ibm_is_instance.cp_master[ 2 ].name}.${var.cluster_name}.${var.domain_name}:22623 check

      backend router_http
        mode tcp
        server ${ibm_is_instance.cp_worker[ 0 ].name}.${var.cluster_name}.${var.domain_name}:80 check
        server ${ibm_is_instance.cp_worker[ 1 ].name}.${var.cluster_name}.${var.domain_name}:80 check

      backend router_https
        mode tcp
        server ${ibm_is_instance.cp_worker[ 0 ].name}.${var.cluster_name}.${var.domain_name}:443 check
        server ${ibm_is_instance.cp_worker[ 1 ].name}.${var.cluster_name}.${var.domain_name}:443 check
    EOT
  }

  provisioner "remote-exec" {
    script = "${path.module}/../../lib/scripts/ubuntu_18/do_reboot.sh"
  }
}

resource "ibm_is_instance" "name_server" {
  name           = "name-server"
  image          = data.ibm_is_image.ubuntu_1804.id
  profile        = "bx2-2x8"
  vpc            = module.vpc.id
  zone           = module.vpc.vpc_subnet.zone
  keys           = [ ibm_is_ssh_key.vpc_key.id ]
  resource_group = data.ibm_resource_group.resource_group.id

  primary_network_interface {
    name            = "eth0"
    subnet          = module.vpc.vpc_subnet.id
    security_groups = [ module.vpc.security_groups[ "vpc_default" ] ]
  }

  connection {
    type                = "ssh"
    bastion_user        = "root"
    bastion_private_key = file( var.bastion_key )
    bastion_host        = module.vpc.bastion_fip
    host                = ibm_is_instance.name_server.primary_network_interface[ 0 ].primary_ipv4_address
    user                = "root"
    private_key         = file( local.vpc_key )
  }

  provisioner "remote-exec" {
    scripts = [
      "${path.module}/../../lib/scripts/ubuntu_18/upgrade_os.sh",
      "${path.module}/../../lib/scripts/ubuntu_18/install_dnsmasq.sh" ]
  }

  provisioner "file" {
    source      = var.pull_secret
    destination = "/etc/dnsmasq.conf"

    content = <<-EOT
      port=53
      no-hosts
      addn-hosts=/etc/dnsmasq.hosts
      log-queries
      domain-needed
      bogus-priv
      expand-hosts
      local=/${var.cluster_name}.${var.domain_name}/
      domain=${var.cluster_name}.${var.domain_name}

      host-record=api.${var.cluster_name}.${var.domain_name}.,${ibm_is_instance.haproxy_server.primary_network_interface[ 0 ].primary_ipv4_address}
      host-record=api-int.${var.cluster_name}.${var.domain_name}.,${ibm_is_instance.haproxy_server.primary_network_interface[ 0 ].primary_ipv4_address}
      host-record=*.apps.${var.cluster_name}.${ibm_is_instance.haproxy_server.primary_network_interface[ 0 ].primary_ipv4_address}
      host-record=etcd-0.${var.cluster_name}.${var.domain_name}.,${ibm_is_instance.cp_master[ 0 ].primary_network_interface[ 0 ].primary_ipv4_address}
      host-record=etcd-1.${var.cluster_name}.${var.domain_name}.,${ibm_is_instance.cp_master[ 1 ].primary_network_interface[ 0 ].primary_ipv4_address}
      host-record=etcd-2.${var.cluster_name}.${var.domain_name}.,${ibm_is_instance.cp_master[ 2 ].primary_network_interface[ 0 ].primary_ipv4_address}
      srv-host=_etcd-server-ssl._tcp.${var.cluster_name}.${var.domain_name}.,etcd-0.${var.cluster_name}.${var.domain_name},2380,0,10
      srv-host=_etcd-server-ssl._tcp.${var.cluster_name}.${var.domain_name}.,etcd-1.${var.cluster_name}.${var.domain_name},2380,0,10
      srv-host=_etcd-server-ssl._tcp.${var.cluster_name}.${var.domain_name}.,etcd-2.${var.cluster_name}.${var.domain_name},2380,0,10
    EOT
  }

  provisioner "remote-exec" {
    script = "${path.module}/../../lib/scripts/ubuntu_18/do_reboot.sh"
  }

  provisioner "remote-exec" {
    connection {
      type                = "ssh"
      bastion_user        = "root"
      bastion_private_key = file( var.bastion_key )
      bastion_host        = module.vpc.bastion_fip
      host                = ibm_is_instance.install_server.primary_network_interface[ 0 ].primary_ipv4_address
      user                = "root"
      private_key         = file( local.vpc_key )
    }

    script = "${path.module}/../../lib/scripts/ubuntu_18/config_resolve.sh ${ibm_is_instance.name_server.primary_network_interface[ 0 ].primary_ipv4_address} ${var.domain_name}"
  }
}

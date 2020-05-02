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

resource "ibm_is_instance" "master" {
  count = 3

  name           = "master-${count.index + 1}"
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

resource "ibm_is_instance" "worker" {
  count = 2

  name           = "worker-${count.index + 1}"
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

resource "ibm_is_instance" "installer" {
  name           = "installer"
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
    host                = ibm_is_instance.installer.primary_network_interface[ 0 ].primary_ipv4_address
    user                = "root"
    private_key         = file( local.vpc_key )
  }

  provisioner "remote-exec" {
    scripts = [
      "${path.module}/../../lib/scripts/ubuntu_18/upgrade_os.sh",
      "${path.module}/../../lib/scripts/ubuntu_18/install_sinatra.sh",
      "${path.module}/lib/scripts/install_openshift_client.sh",
      "${path.module}/../../lib/scripts/ubuntu_18/do_reboot.sh" ]
  }

  provisioner "file" {
    source      = var.pull_secret
    destination = "/opt/openshift/etc/pull_secret.txt"
  }

  provisioner "file" {
    source      = "${path.module}/main.auto.tfvars"
    destination = "/opt/openshift/etc/main.auto.tfvars"
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat ${path.module}/lib/scripts/config_openshift_installation.sh \
        | ssh -o StrictHostKeyChecking=accept-new \
              -o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=accept-new -i ${var.bastion_key} root@${module.vpc.bastion_fip}" -i ${var.cluster_key} root@${ibm_is_instance.installer.primary_network_interface[ 0 ].primary_ipv4_address} \
              bash -s - ${var.cluster_name} ${var.domain_name}
    EOT
  }
}

resource "ibm_is_instance" "load_balancer" {
  name           = "load-balancer"
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
    host                = ibm_is_instance.load_balancer.primary_network_interface[ 0 ].primary_ipv4_address
    user                = "root"
    private_key         = file( local.vpc_key )
  }

  provisioner "remote-exec" {
    scripts = [
      "${path.module}/../../lib/scripts/ubuntu_18/upgrade_os.sh",
      "${path.module}/../../lib/scripts/ubuntu_18/install_haproxy.sh" ]
  }

  provisioner "file" {
    destination = "/etc/haproxy/haproxy.cfg"

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

      frontend openshift_api_server
        mode tcp
        option tcplog
        bind api.${var.cluster_name}.${var.domain_name}:6443
        default_backend openshift_api_server

      backend openshift_api_server
        mode tcp
        balance source
        server ${ibm_is_instance.installer.name}.${var.cluster_name}.${var.domain_name}:6443 check
        server ${ibm_is_instance.master[ 0 ].name}.${var.cluster_name}.${var.domain_name}:6443 check
        server ${ibm_is_instance.master[ 1 ].name}.${var.cluster_name}.${var.domain_name}:6443 check
        server ${ibm_is_instance.master[ 2 ].name}.${var.cluster_name}.${var.domain_name}:6443 check

      frontend machine_config_server
        mode tcp
        option tcplog
        bind *:22623
        default_backend machine_config_server

      backend machine_config_server
        mode tcp
        balance source
        server ${ibm_is_instance.installer.name}.${var.cluster_name}.${var.domain_name}:22623 check
        server ${ibm_is_instance.master[ 0 ].name}.${var.cluster_name}.${var.domain_name}:22623 check
        server ${ibm_is_instance.master[ 1 ].name}.${var.cluster_name}.${var.domain_name}:22623 check
        server ${ibm_is_instance.master[ 2 ].name}.${var.cluster_name}.${var.domain_name}:22623 check

      frontend ingress_http
        mode tcp
        option tcplog
        bind *:80
        default_backend ingress_http

      backend ingress_http
        mode tcp
        server ${ibm_is_instance.worker[ 0 ].name}.${var.cluster_name}.${var.domain_name}:80 check
        server ${ibm_is_instance.worker[ 1 ].name}.${var.cluster_name}.${var.domain_name}:80 check

      frontend ingress_https
        mode tcp
        option tcplog
        bind *:443
        default_backend ingress_https

      backend ingress_https
        mode tcp
        server ${ibm_is_instance.worker[ 0 ].name}.${var.cluster_name}.${var.domain_name}:443 check
        server ${ibm_is_instance.worker[ 1 ].name}.${var.cluster_name}.${var.domain_name}:443 check
    EOT
  }
}

resource "ibm_is_instance" "nameserver" {
  name           = "nameserver"
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
    host                = ibm_is_instance.nameserver.primary_network_interface[ 0 ].primary_ipv4_address
    user                = "root"
    private_key         = file( local.vpc_key )
  }

  provisioner "remote-exec" {
    scripts = [
      "${path.module}/../../lib/scripts/ubuntu_18/upgrade_os.sh",
      "${path.module}/../../lib/scripts/ubuntu_18/install_dnsmasq.sh" ]
  }

  provisioner "file" {
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

      host-record=api.${var.cluster_name}.${var.domain_name}.,${ibm_is_instance.load_balancer.primary_network_interface[ 0 ].primary_ipv4_address}
      host-record=api-int.${var.cluster_name}.${var.domain_name}.,${ibm_is_instance.load_balancer.primary_network_interface[ 0 ].primary_ipv4_address}
      host-record=*.apps.${var.cluster_name}.${var.domain_name}.,${ibm_is_instance.load_balancer.primary_network_interface[ 0 ].primary_ipv4_address}
      host-record=etcd-0.${var.cluster_name}.${var.domain_name}.,${ibm_is_instance.master[ 0 ].primary_network_interface[ 0 ].primary_ipv4_address}
      host-record=etcd-1.${var.cluster_name}.${var.domain_name}.,${ibm_is_instance.master[ 1 ].primary_network_interface[ 0 ].primary_ipv4_address}
      host-record=etcd-2.${var.cluster_name}.${var.domain_name}.,${ibm_is_instance.master[ 2 ].primary_network_interface[ 0 ].primary_ipv4_address}
      srv-host=_etcd-server-ssl._tcp.${var.cluster_name}.${var.domain_name}.,etcd-0.${var.cluster_name}.${var.domain_name},2380,0,10
      srv-host=_etcd-server-ssl._tcp.${var.cluster_name}.${var.domain_name}.,etcd-1.${var.cluster_name}.${var.domain_name},2380,0,10
      srv-host=_etcd-server-ssl._tcp.${var.cluster_name}.${var.domain_name}.,etcd-2.${var.cluster_name}.${var.domain_name},2380,0,10
    EOT
  }

  provisioner "file" {
    destination = "/etc/dnsmasq.hosts"
    content = <<-EOT
      ${ibm_is_instance.installer.primary_network_interface[ 0 ].primary_ipv4_address} ${ibm_is_instance.installer.name}.${var.cluster_name}.${var.domain_name}          in.${var.cluster_name}.${var.domain_name}
      ${ibm_is_instance.load_balancer.primary_network_interface[ 0 ].primary_ipv4_address} ${ibm_is_instance.load_balancer.name}.${var.cluster_name}.${var.domain_name}  lb.${var.cluster_name}.${var.domain_name}
      ${ibm_is_instance.nameserver.primary_network_interface[ 0 ].primary_ipv4_address} ${ibm_is_instance.nameserver.name}.${var.cluster_name}.${var.domain_name}        ns.${var.cluster_name}.${var.domain_name}
      ${ibm_is_instance.master[ 0 ].primary_network_interface[ 0 ].primary_ipv4_address} ${ibm_is_instance.master[ 0 ].name}.${var.cluster_name}.${var.domain_name}      m1.${var.cluster_name}.${var.domain_name}
      ${ibm_is_instance.master[ 1 ].primary_network_interface[ 0 ].primary_ipv4_address} ${ibm_is_instance.master[ 1 ].name}.${var.cluster_name}.${var.domain_name}      m2.${var.cluster_name}.${var.domain_name}
      ${ibm_is_instance.master[ 2 ].primary_network_interface[ 0 ].primary_ipv4_address} ${ibm_is_instance.master[ 2 ].name}.${var.cluster_name}.${var.domain_name}      m3.${var.cluster_name}.${var.domain_name}
      ${ibm_is_instance.worker[ 0 ].primary_network_interface[ 0 ].primary_ipv4_address} ${ibm_is_instance.worker[ 0 ].name}.${var.cluster_name}.${var.domain_name}      w1.${var.cluster_name}.${var.domain_name}
      ${ibm_is_instance.worker[ 1 ].primary_network_interface[ 0 ].primary_ipv4_address} ${ibm_is_instance.worker[ 1 ].name}.${var.cluster_name}.${var.domain_name}      w2.${var.cluster_name}.${var.domain_name}
    EOT
  }

  provisioner "remote-exec" {
    script = "${path.module}/../../lib/scripts/ubuntu_18/do_reboot.sh"
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat ${path.module}/../../lib/scripts/ubuntu_18/config_resolve.sh \
        | ssh -o StrictHostKeyChecking=accept-new \
              -o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=accept-new -i ${var.bastion_key} root@${module.vpc.bastion_fip}" -i ${var.cluster_key} root@${ibm_is_instance.installer.primary_network_interface[ 0 ].primary_ipv4_address} \
              bash -s - ${ibm_is_instance.nameserver.primary_network_interface[ 0 ].primary_ipv4_address} ${var.domain_name}
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat ${path.module}/../../lib/scripts/ubuntu_18/config_resolve.sh \
        | ssh -o StrictHostKeyChecking=accept-new \
              -o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=accept-new -i ${var.bastion_key} root@${module.vpc.bastion_fip}" -i ${var.cluster_key} root@${ibm_is_instance.load_balancer.primary_network_interface[ 0 ].primary_ipv4_address} \
              bash -s - ${ibm_is_instance.nameserver.primary_network_interface[ 0 ].primary_ipv4_address} ${var.domain_name}
    EOT
  }
}

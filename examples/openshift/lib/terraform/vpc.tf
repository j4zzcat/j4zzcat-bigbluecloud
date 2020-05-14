data "ibm_resource_group" "resource_group" {
  name = var.resource_group_name
}

module "vpc" {
  source = "/h/repo/lib/terraform/vpc"

  name                = var.cluster_name
  zone_name           = var.zone_name
  classic_access      = true
  transit_gateway     = false
  bastion             = true
  bastion_key         = var.bastion_key
  resource_group_id   = data.ibm_resource_group.resource_group.id
}

####
# Cluster Key
#

resource "ibm_is_ssh_key" "cluster_key" {
  name           = "${var.cluster_name}-cluster-key"
  public_key     = file( "${var.cluster_key}.pub" )
  resource_group = data.ibm_resource_group.resource_group.id
}

####
# Provision the installer
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
  keys           = [ ibm_is_ssh_key.cluster_key.id ]
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
    private_key         = file( var.cluster_key )
  }

  provisioner "remote-exec" {
    scripts = [
      "${local.j4zzcat_ubuntu_18_scripts_dir}/upgrade_os.sh",
      "${local.j4zzcat_ubuntu_18_scripts_dir}/config_resolve.sh",
      "${local.j4zzcat_ubuntu_18_scripts_dir}/install_sinatra.sh",
      "${local.openshift_scripts_dir}/install_openshift_client.sh" ]
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
      cat ${local.openshift_scripts_dir}/config_openshift_installation.sh \
        | ssh -o StrictHostKeyChecking=no \
              -o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=no -i ${var.bastion_key} root@${module.vpc.bastion_fip}" -i ${var.cluster_key} root@${ibm_is_instance.installer.primary_network_interface[ 0 ].primary_ipv4_address} \
              bash -s - ${var.cluster_name} ${var.domain_name}
    EOT
  }

  provisioner "file" {
    source = "${local.openshift_helpers_dir}/bootstrap_helper.rb"
    destination = "/opt/openshift/bin/bootstrap_helper.rb"
  }

  provisioner "remote-exec" {
    script = "${local.j4zzcat_ubuntu_18_scripts_dir}/do_reboot.sh"
  }
}

####
# Provision the Load Balancer
#

resource "ibm_is_instance" "load_balancer" {
  name           = "load-balancer"
  image          = data.ibm_is_image.ubuntu_1804.id
  profile        = "bx2-2x8"
  vpc            = module.vpc.id
  zone           = module.vpc.vpc_subnet.zone
  keys           = [ ibm_is_ssh_key.cluster_key.id ]
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
    private_key         = file( var.cluster_key )
  }

  provisioner "remote-exec" {
    scripts = [
      "${local.j4zzcat_ubuntu_18_scripts_dir}/upgrade_os.sh",
      "${local.j4zzcat_ubuntu_18_scripts_dir}/install_haproxy.sh",
      "${local.j4zzcat_ubuntu_18_scripts_dir}/config_resolve.sh" ]
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
        bind *:6443
        default_backend openshift_api_server

      backend openshift_api_server
        mode tcp
        balance source
        server bootstrap bootstrap.${var.cluster_name}.${var.domain_name}:6443
        server master-1 master-1.${var.cluster_name}.${var.domain_name}:6443
        server master-2 master-2.${var.cluster_name}.${var.domain_name}:6443
        server master-3 master-3.${var.cluster_name}.${var.domain_name}:6443

      frontend machine_config_server
        mode tcp
        option tcplog
        bind *:22623
        default_backend machine_config_server

      backend machine_config_server
        mode tcp
        balance source
        server bootstrap bootstrap.${var.cluster_name}.${var.domain_name}:22623
        server master-1 master-1.${var.cluster_name}.${var.domain_name}:22623
        server master-2 master-2.${var.cluster_name}.${var.domain_name}:22623
        server master-3 master-3.${var.cluster_name}.${var.domain_name}:22623

      frontend ingress_http
        mode tcp
        option tcplog
        bind *:80
        default_backend ingress_http

      backend ingress_http
        mode tcp
        server worker-1 worker-1.${var.cluster_name}.${var.domain_name}:80
        server worker-2 worker-2.${var.cluster_name}.${var.domain_name}:80

      frontend ingress_https
        mode tcp
        option tcplog
        bind *:443
        default_backend ingress_https

      backend ingress_https
        mode tcp
        server worker-1 worker-1.${var.cluster_name}.${var.domain_name}:443
        server worker-2 worker-2.${var.cluster_name}.${var.domain_name}:443
    EOT
  }
}

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
  classic_access      = false
  transit_gateway     = false
  dns_service         = true
  dns_domain_name     = var.domain_name
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

resource "ibm_is_instance" "bootstrap" {
  name           = "bootstrap"
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

###
# Provision some workers
#

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
      "${path.module}/../../lib/scripts/ubuntu_18/config_resolve.sh",
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

  provisioner "file" {
    source = "${path.module}/lib/helpers/bootstrap_helper.rb"
    destination = "/opt/openshift/bin/bootstrap_helper.rb"
  }

  # provisioner "remote-exec" {
  #   inline = [ "/opt/openshift/bin/openshift-install --dir=/opt/openshift/install wait-for bootstrap-complete --log-level=info > ~/openshift.log &" ]
  # }
  #
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
      "${path.module}/../../lib/scripts/ubuntu_18/install_haproxy.sh",
      "${path.module}/../../lib/scripts/ubuntu_18/config_resolve.sh" ]
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
        server bootstrap ${ibm_is_instance.bootstrap.name}.${var.cluster_name}.${var.domain_name}:6443
        server master-1 ${ibm_is_instance.master[ 0 ].name}.${var.cluster_name}.${var.domain_name}:6443
        server master-2 ${ibm_is_instance.master[ 1 ].name}.${var.cluster_name}.${var.domain_name}:6443
        server master-3 ${ibm_is_instance.master[ 2 ].name}.${var.cluster_name}.${var.domain_name}:6443

      frontend machine_config_server
        mode tcp
        option tcplog
        bind *:22623
        default_backend machine_config_server

      backend machine_config_server
        mode tcp
        balance source
        server bootstrap ${ibm_is_instance.bootstrap.name}.${var.cluster_name}.${var.domain_name}:22623
        server master-1 ${ibm_is_instance.master[ 0 ].name}.${var.cluster_name}.${var.domain_name}:22623
        server master-2 ${ibm_is_instance.master[ 1 ].name}.${var.cluster_name}.${var.domain_name}:22623
        server master-3 ${ibm_is_instance.master[ 2 ].name}.${var.cluster_name}.${var.domain_name}:22623

      frontend ingress_http
        mode tcp
        option tcplog
        bind *:80
        default_backend ingress_http

      backend ingress_http
        mode tcp
        server worker-1 ${ibm_is_instance.worker[ 0 ].name}.${var.cluster_name}.${var.domain_name}:80
        server worker-2 ${ibm_is_instance.worker[ 1 ].name}.${var.cluster_name}.${var.domain_name}:80

      frontend ingress_https
        mode tcp
        option tcplog
        bind *:443
        default_backend ingress_https

      backend ingress_https
        mode tcp
        server worker-1 ${ibm_is_instance.worker[ 0 ].name}.${var.cluster_name}.${var.domain_name}:443
        server worker-2 ${ibm_is_instance.worker[ 1 ].name}.${var.cluster_name}.${var.domain_name}:443
    EOT
  }
}

locals {
  hostname_records = {
    "${ibm_is_instance.installer.name}.${var.cluster_name}"     = ibm_is_instance.installer.primary_network_interface[ 0 ].primary_ipv4_address,
    "${ibm_is_instance.load_balancer.name}.${var.cluster_name}" = ibm_is_instance.load_balancer.primary_network_interface[ 0 ].primary_ipv4_address,
    "${ibm_is_instance.bootstrap.name}.${var.cluster_name}"     = ibm_is_instance.bootstrap.primary_network_interface[ 0 ].primary_ipv4_address,
    "${ibm_is_instance.master[ 0 ].name}.${var.cluster_name}"   = ibm_is_instance.master[ 0 ].primary_network_interface[ 0 ].primary_ipv4_address,
    "${ibm_is_instance.master[ 1 ].name}.${var.cluster_name}"   = ibm_is_instance.master[ 1 ].primary_network_interface[ 0 ].primary_ipv4_address,
    "${ibm_is_instance.master[ 2 ].name}.${var.cluster_name}"   = ibm_is_instance.master[ 2 ].primary_network_interface[ 0 ].primary_ipv4_address,
    "${ibm_is_instance.worker[ 0 ].name}.${var.cluster_name}"   = ibm_is_instance.worker[ 0 ].primary_network_interface[ 0 ].primary_ipv4_address,
    "${ibm_is_instance.worker[ 1 ].name}.${var.cluster_name}"   = ibm_is_instance.worker[ 1 ].primary_network_interface[ 0 ].primary_ipv4_address,
    # "api.${var.cluster_name}.${var.domain_name}"     = ibm_is_instance.load_balancer.primary_network_interface[ 0 ].primary_ipv4_address,
    # "api-int.${var.cluster_name}.${var.domain_name}" = ibm_is_instance.load_balancer.primary_network_interface[ 0 ].primary_ipv4_address,
    # "*.apps.${var.cluster_name}.${var.domain_name}"  = ibm_is_instance.load_balancer.primary_network_interface[ 0 ].primary_ipv4_address,
    # "etcd-0.${var.cluster_name}.${var.domain_name}"  = ibm_is_instance.master[ 0 ].primary_network_interface[ 0 ].primary_ipv4_address,
    # "etcd-1.${var.cluster_name}.${var.domain_name}"  = ibm_is_instance.master[ 1 ].primary_network_interface[ 0 ].primary_ipv4_address,
    # "etcd-2.${var.cluster_name}.${var.domain_name}"  = ibm_is_instance.master[ 2 ].primary_network_interface[ 0 ].primary_ipv4_address
  }
}

resource "ibm_dns_resource_record" "hostname_records" {
  count = length( local.hostname_records )

  instance_id = module.vpc.dns_service_instance_id
  zone_id     = module.vpc.dns_service_zone_id
  type        = "A"
  name        = keys( local.hostname_records )[ count.index ]
  rdata       = values( local.hostname_records )[ count.index ]
  ttl         = 3600
}

# resource "ibm_dns_resource_record" "srv_records" {
#   count = 3
#
#   instance_id = module.vpc.dns_service_instance_id
#   zone_id     = module.vpc.dns_service_zone_id
#   type        = "SRV"
#   name        = "etcd-${count.index}"
#   rdata       = "${var.cluster_name}.${var.domain_name}"
#   priority    = 0
#   weight      = 10
#   port        = 2380
#   service     = "_etcd-server-ssl"
#   protocol    = "tcp"
#   ttl         = 43200
# }



# resource "ibm_dns_resource_record" "test-pdns-resource-record-aaaa" {
#   instance_id = ibm_resource_instance.test-pdns-instance.guid
#   zone_id     = ibm_dns_zone.test-pdns-zone.zone_id
#   type        = "AAAA"
#   name        = "testAAAA"
#   rdata       = "2001:0db8:0012:0001:3c5e:7354:0000:5db5"
# }
#
# resource "ibm_dns_resource_record" "test-pdns-resource-record-cname" {
#   instance_id = ibm_resource_instance.test-pdns-instance.guid
#   zone_id     = ibm_dns_zone.test-pdns-zone.zone_id
#   type        = "CNAME"
#   name        = "testCNAME"
#   rdata       = "test.com"
# }
#
# resource "ibm_dns_resource_record" "test-pdns-resource-record-ptr" {
#   instance_id = ibm_resource_instance.test-pdns-instance.guid
#   zone_id     = ibm_dns_zone.test-pdns-zone.zone_id
#   type        = "PTR"
#   name        = "1.2.3.4"
#   rdata       = "testA.test.com"
# }
#
# resource "ibm_dns_resource_record" "test-pdns-resource-record-mx" {
#   instance_id = ibm_resource_instance.test-pdns-instance.guid
#   zone_id     = ibm_dns_zone.test-pdns-zone.zone_id
#   type        = "MX"
#   name        = "testMX"
#   rdata       = "mailserver.test.com"
#   preference  = 10
# }
#
# resource "ibm_dns_resource_record" "test-pdns-resource-record-srv" {
#   instance_id = ibm_resource_instance.test-pdns-instance.guid
#   zone_id     = ibm_dns_zone.test-pdns-zone.zone_id
#   type        = "SRV"
#   name        = "testSRV"
#   rdata       = "tester.com"
#   priority    = 100
#   weight      = 100
#   port        = 8000
#   service     = "_sip"
#   protocol    = "udp"
# }
#
# resource "ibm_dns_resource_record" "test-pdns-resource-record-txt" {
#   instance_id = ibm_resource_instance.test-pdns-instance.guid
#   zone_id     = ibm_dns_zone.test-pdns-zone.zone_id
#   type        = "TXT"
#   name        = "testTXT"
#   rdata       = "textinformation"
#   ttl         = 900

# resource "ibm_is_instance" "nameserver" {
#   name           = "nameserver"
#   image          = data.ibm_is_image.ubuntu_1804.id
#   profile        = "bx2-2x8"
#   vpc            = module.vpc.id
#   zone           = module.vpc.vpc_subnet.zone
#   keys           = [ ibm_is_ssh_key.vpc_key.id ]
#   resource_group = data.ibm_resource_group.resource_group.id
#
#   primary_network_interface {
#     name            = "eth0"
#     subnet          = module.vpc.vpc_subnet.id
#     security_groups = [ module.vpc.security_groups[ "vpc_default" ] ]
#   }
#
#   connection {
#     type                = "ssh"
#     bastion_user        = "root"
#     bastion_private_key = file( var.bastion_key )
#     bastion_host        = module.vpc.bastion_fip
#     host                = ibm_is_instance.nameserver.primary_network_interface[ 0 ].primary_ipv4_address
#     user                = "root"
#     private_key         = file( local.vpc_key )
#   }
#
#   provisioner "remote-exec" {
#     scripts = [
#       "${path.module}/../../lib/scripts/ubuntu_18/upgrade_os.sh",
#       "${path.module}/../../lib/scripts/ubuntu_18/install_dnsmasq.sh",
#       "${path.module}/../../lib/scripts/ubuntu_18/do_reboot.sh" ]
#   }
#
#   provisioner "file" {
#     destination = "/etc/dnsmasq.conf"
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
#       host-record=api.${var.cluster_name}.${var.domain_name}.,${ibm_is_instance.load_balancer.primary_network_interface[ 0 ].primary_ipv4_address}
#       host-record=api-int.${var.cluster_name}.${var.domain_name}.,${ibm_is_instance.load_balancer.primary_network_interface[ 0 ].primary_ipv4_address}
#       host-record=*.apps.${var.cluster_name}.${var.domain_name}.,${ibm_is_instance.load_balancer.primary_network_interface[ 0 ].primary_ipv4_address}
#       host-record=etcd-0.${var.cluster_name}.${var.domain_name}.,${ibm_is_instance.master[ 0 ].primary_network_interface[ 0 ].primary_ipv4_address}
#       host-record=etcd-1.${var.cluster_name}.${var.domain_name}.,${ibm_is_instance.master[ 1 ].primary_network_interface[ 0 ].primary_ipv4_address}
#       host-record=etcd-2.${var.cluster_name}.${var.domain_name}.,${ibm_is_instance.master[ 2 ].primary_network_interface[ 0 ].primary_ipv4_address}
#       srv-host=_etcd-server-ssl._tcp.${var.cluster_name}.${var.domain_name}.,etcd-0.${var.cluster_name}.${var.domain_name},2380,0,10
#       srv-host=_etcd-server-ssl._tcp.${var.cluster_name}.${var.domain_name}.,etcd-1.${var.cluster_name}.${var.domain_name},2380,0,10
#       srv-host=_etcd-server-ssl._tcp.${var.cluster_name}.${var.domain_name}.,etcd-2.${var.cluster_name}.${var.domain_name},2380,0,10
#     EOT
#   }
#
#   provisioner "file" {
#     destination = "/etc/dnsmasq.hosts"
#     content = <<-EOT
#       ${ibm_is_instance.installer.primary_network_interface[ 0 ].primary_ipv4_address} ${ibm_is_instance.installer.name}.${var.cluster_name}.${var.domain_name}          in.${var.cluster_name}.${var.domain_name}
#       ${ibm_is_instance.load_balancer.primary_network_interface[ 0 ].primary_ipv4_address} ${ibm_is_instance.load_balancer.name}.${var.cluster_name}.${var.domain_name}  lb.${var.cluster_name}.${var.domain_name}
#       ${ibm_is_instance.nameserver.primary_network_interface[ 0 ].primary_ipv4_address} ${ibm_is_instance.nameserver.name}.${var.cluster_name}.${var.domain_name}        ns.${var.cluster_name}.${var.domain_name}
#       ${ibm_is_instance.bootstrap.primary_network_interface[ 0 ].primary_ipv4_address} ${ibm_is_instance.bootstrap.name}.${var.cluster_name}.${var.domain_name}          bs.${var.cluster_name}.${var.domain_name}
#       ${ibm_is_instance.master[ 0 ].primary_network_interface[ 0 ].primary_ipv4_address} ${ibm_is_instance.master[ 0 ].name}.${var.cluster_name}.${var.domain_name}      m1.${var.cluster_name}.${var.domain_name}
#       ${ibm_is_instance.master[ 1 ].primary_network_interface[ 0 ].primary_ipv4_address} ${ibm_is_instance.master[ 1 ].name}.${var.cluster_name}.${var.domain_name}      m2.${var.cluster_name}.${var.domain_name}
#       ${ibm_is_instance.master[ 2 ].primary_network_interface[ 0 ].primary_ipv4_address} ${ibm_is_instance.master[ 2 ].name}.${var.cluster_name}.${var.domain_name}      m3.${var.cluster_name}.${var.domain_name}
#       ${ibm_is_instance.worker[ 0 ].primary_network_interface[ 0 ].primary_ipv4_address} ${ibm_is_instance.worker[ 0 ].name}.${var.cluster_name}.${var.domain_name}      w1.${var.cluster_name}.${var.domain_name}
#       ${ibm_is_instance.worker[ 1 ].primary_network_interface[ 0 ].primary_ipv4_address} ${ibm_is_instance.worker[ 1 ].name}.${var.cluster_name}.${var.domain_name}      w2.${var.cluster_name}.${var.domain_name}
#     EOT
#   }
#
#   provisioner "remote-exec" {
#     inline = [ "systemctl restart dnsmasq" ]
#   }
#
#   provisioner "local-exec" {
#     command = <<-EOT
#       cat ${path.module}/../../lib/scripts/ubuntu_18/config_resolve.sh \
#         | ssh -o StrictHostKeyChecking=accept-new \
#               -o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=accept-new -i ${var.bastion_key} root@${module.vpc.bastion_fip}" -i ${var.cluster_key} root@${ibm_is_instance.installer.primary_network_interface[ 0 ].primary_ipv4_address} \
#               bash -s - ${ibm_is_instance.nameserver.primary_network_interface[ 0 ].primary_ipv4_address} ${var.domain_name}
#     EOT
#   }
#
#   provisioner "local-exec" {
#     command = <<-EOT
#       cat ${path.module}/../../lib/scripts/ubuntu_18/config_resolve.sh \
#         | ssh -o StrictHostKeyChecking=accept-new \
#               -o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=accept-new -i ${var.bastion_key} root@${module.vpc.bastion_fip}" -i ${var.cluster_key} root@${ibm_is_instance.load_balancer.primary_network_interface[ 0 ].primary_ipv4_address} \
#               bash -s - ${ibm_is_instance.nameserver.primary_network_interface[ 0 ].primary_ipv4_address} ${var.domain_name}
#     EOT
#   }
# }

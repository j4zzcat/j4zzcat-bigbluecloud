variable cluster_name        {}
variable domain_name         {}
variable region_name         {}
variable zone_name           {}
variable data_center_name    {}
variable resource_group_name {}
variable bastion_key         {}
variable cluster_key         {}
variable pull_secret         {}

provider "ibm" {
  region     = var.region_name
  generation = 2
}

data "ibm_resource_group" "resource_group" {
  name = var.resource_group_name
}

module "vpc" {
  source = "/h/repo/lib/terraform/vpc"

  name                = var.cluster_name
  zone_name           = var.zone_name
  classic_access      = true
  transit_gateway     = false
  dns_service         = true
  dns_domain_name     = var.domain_name
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

###
# Provision the control plane
#

resource "ibm_is_instance" "bootstrap" {
  name           = "bootstrap"
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
}

# --- VPC ---

# resource "ibm_is_instance" "master" {
#   count = 3
#
#   name           = "master-${count.index + 1}"
#   image          = data.ibm_is_image.ubuntu_1804.id
#   profile        = "bx2-2x8"
#   vpc            = module.vpc.id
#   zone           = module.vpc.vpc_subnet.zone
#   keys           = [ ibm_is_ssh_key.cluster_key.id ]
#   resource_group = data.ibm_resource_group.resource_group.id
#
#   primary_network_interface {
#     name            = "eth0"
#     subnet          = module.vpc.vpc_subnet.id
#     security_groups = [ module.vpc.security_groups[ "vpc_default" ] ]
#   }
# }

# resource "ibm_is_instance" "worker" {
#   count = 2
#
#   name           = "worker-${count.index + 1}"
#   image          = data.ibm_is_image.ubuntu_1804.id
#   profile        = "bx2-2x8"
#   vpc            = module.vpc.id
#   zone           = module.vpc.vpc_subnet.zone
#   keys           = [ ibm_is_ssh_key.cluster_key.id ]
#   resource_group = data.ibm_resource_group.resource_group.id
#
#   primary_network_interface {
#     name            = "eth0"
#     subnet          = module.vpc.vpc_subnet.id
#     security_groups = [ module.vpc.security_groups[ "vpc_default" ] ]
#   }
# }

# --- IAAS ---

resource "ibm_compute_ssh_key" "cluster_key" {
  label      = "${var.cluster_name}-cluster-key"
  public_key = file( "${var.cluster_key}.pub" )
}

resource "ibm_compute_vm_instance" "public_gateway" {
  hostname             = "public-gateway"
  domain               = "${var.cluster_name}.${var.domain_name}"
  os_reference_code    = "UBUNTU_18_64"
  datacenter           = var.data_center_name
  hourly_billing       = true
  private_network_only = false
  cores                = 1
  memory               = 1024

  ssh_key_ids = [
    ibm_compute_ssh_key.cluster_key.id
  ]

  provisioner "remote-exec" {
    inline = [
      "ufw enable",
      "echo 'net/ipv4/ip_forward=1' >> /etc/ufw/sysctl.conf",
      "touch /etc/rc.local",
      "chmod 755 /etc/rc.local",
      "echo iptables -P INPUT DROP >>/etc/rc.local",
      "echo iptables -P FORWARD DROP >>/etc/rc.local",
      "echo iptables -A INPUT -i lo -j ACCEPT >>/etc/rc.local",
      "echo iptables -A INPUT -i eth0 -j ACCEPT >>/etc/rc.local",
      "echo iptables -A INPUT -i eth1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT >>/etc/rc.local",
      "echo iptables -A FORWARD -i eth0 -d 10.0.0.0/8 -o eth0 -j ACCEPT >>/etc/rc.local",
      "echo iptables -A FORWARD -i eth0 -o eth1 -j ACCEPT >>/etc/rc.local",
      "echo iptables -A FORWARD -i eth1 -o eth0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT >>/etc/rc.local",
      "echo iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE >>/etc/rc.local",
      "echo exit 0 >>/etc/rc.local"
    ]
  }
}

resource "ibm_compute_vm_instance" "master" {
  count = 3

  hostname             = "master-${count.index + 1}"
  domain               = "${var.cluster_name}.${var.domain_name}"
  os_reference_code    = "UBUNTU_18_64"
  datacenter           = var.data_center_name
  hourly_billing       = true
  private_network_only = false
  cores                = 1
  memory               = 1024
  ssh_key_ids = [
    ibm_compute_ssh_key.cluster_key.id
  ]

  provisioner "remote-exec" {
    inline = [
      "ip route del default",
      "ip route add default via ${ibm_compute_vm_instance.public_gateway.ipv4_address_private} dev eth0"
    ]
  }
}

resource "ibm_compute_vm_instance" "worker" {
  count = 3

  hostname             = "worker-${count.index + 1}"
  domain               = "${var.cluster_name}.${var.domain_name}"
  os_reference_code    = "UBUNTU_18_64"
  datacenter           = var.data_center_name
  hourly_billing       = true
  private_network_only = false
  cores                = 1
  memory               = 1024
  ssh_key_ids = [
    ibm_compute_ssh_key.cluster_key.id
  ]

  provisioner "remote-exec" {
    inline = [
      "ip route del default",
      "ip route add default via ${ibm_compute_vm_instance.public_gateway.ipv4_address_private} dev eth0"
    ]
  }
}


locals {
  # bootstrap_pip = "${ibm_is_instance.bootstrap.primary_network_interface[ 0 ].primary_ipv4_address}"
  # master_1_pip  = "${ibm_is_instance.master[ 0 ].primary_network_interface[ 0 ].primary_ipv4_address}"
  # master_2_pip  = "${ibm_is_instance.master[ 1 ].primary_network_interface[ 0 ].primary_ipv4_address}"
  # master_3_pip  = "${ibm_is_instance.master[ 2 ].primary_network_interface[ 0 ].primary_ipv4_address}"
  # worker_1_pip  = "${ibm_is_instance.worker[ 0 ].primary_network_interface[ 0 ].primary_ipv4_address}"
  # worker_2_pip  = "${ibm_is_instance.worker[ 1 ].primary_network_interface[ 0 ].primary_ipv4_address}"

  bootstrap_pip = "${ibm_is_instance.bootstrap.primary_network_interface[ 0 ].primary_ipv4_address}"
  master_1_pip  = "${ibm_compute_vm_instance.master[ 0 ].ipv4_address_private}"
  master_2_pip  = "${ibm_compute_vm_instance.master[ 1 ].ipv4_address_private}"
  master_3_pip  = "${ibm_compute_vm_instance.master[ 2 ].ipv4_address_private}"
  worker_1_pip  = "${ibm_compute_vm_instance.worker[ 0 ].ipv4_address_private}"
  worker_2_pip  = "${ibm_compute_vm_instance.worker[ 1 ].ipv4_address_private}"
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
      "/h/repo/lib/scripts/ubuntu_18/upgrade_os.sh",
      "/h/repo/lib/scripts/ubuntu_18/config_resolve.sh",
      "/h/repo/lib/scripts/ubuntu_18/install_sinatra.sh",
      "${path.module}/../scripts/install_openshift_client.sh" ]
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
      cat ${path.module}/../scripts/config_openshift_installation.sh \
        | ssh -o StrictHostKeyChecking=no \
              -o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=no -i ${var.bastion_key} root@${module.vpc.bastion_fip}" -i ${var.cluster_key} root@${ibm_is_instance.installer.primary_network_interface[ 0 ].primary_ipv4_address} \
              bash -s - ${var.cluster_name} ${var.domain_name}
    EOT
  }

  provisioner "file" {
    source = "${path.module}/../helpers/bootstrap_helper.rb"
    destination = "/opt/openshift/bin/bootstrap_helper.rb"
  }

  provisioner "remote-exec" {
    script = "/h/repo/lib/scripts/ubuntu_18/do_reboot.sh"
  }
}

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
      "/h/repo/lib/scripts/ubuntu_18/upgrade_os.sh",
      "/h/repo/lib/scripts/ubuntu_18/install_haproxy.sh",
      "/h/repo/lib/scripts/ubuntu_18/config_resolve.sh" ]
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

locals {
  hostname_records = {
    "installer.${var.cluster_name}"     = ibm_is_instance.installer.primary_network_interface[ 0 ].primary_ipv4_address,
    "load-balancer.${var.cluster_name}" = ibm_is_instance.load_balancer.primary_network_interface[ 0 ].primary_ipv4_address,
    "bootstrap.${var.cluster_name}"     = local.bootstrap_pip,
    "master-1.${var.cluster_name}"      = local.master_1_pip,
    "master-2.${var.cluster_name}"      = local.master_2_pip,
    "master-3.${var.cluster_name}"      = local.master_3_pip,
    "worker-1.${var.cluster_name}"      = local.worker_1_pip,
    "worker-2.${var.cluster_name}"      = local.worker_2_pip
  }

  alias_records = {
    "api.${var.cluster_name}"     = "load-balancer.${var.cluster_name}.${var.domain_name}",
    "api-int.${var.cluster_name}" = "load-balancer.${var.cluster_name}.${var.domain_name}",
    "*.apps.${var.cluster_name}"  = "load-balancer.${var.cluster_name}.${var.domain_name}",
    "etcd-0.${var.cluster_name}"  = "master-1.${var.cluster_name}.${var.domain_name}",
    "etcd-1.${var.cluster_name}"  = "master-2.${var.cluster_name}.${var.domain_name}",
    "etcd-2.${var.cluster_name}"  = "master-3.${var.cluster_name}.${var.domain_name}"
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

resource "ibm_dns_resource_record" "alias_records" {
  count = length( local.alias_records )

  instance_id = module.vpc.dns_service_instance_id
  zone_id     = module.vpc.dns_service_zone_id
  type        = "CNAME"
  name        = keys( local.alias_records )[ count.index ]
  rdata       = values( local.alias_records )[ count.index ]
  ttl         = 3600
}

resource "ibm_dns_resource_record" "srv_records" {
  count = 3

  instance_id = module.vpc.dns_service_instance_id
  zone_id     = module.vpc.dns_service_zone_id
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

# resource "null_resource" "bootstrap_reboot_to_rhcos" {
#   provisioner "remote-exec" {
#     connection {
#       type                = "ssh"
#       bastion_user        = "root"
#       bastion_private_key = file( var.bastion_key )
#       bastion_host        = module.vpc.bastion_fip
#       host                = local.bootstrap_pip
#       user                = "root"
#       private_key         = file( var.cluster_key )
#     }
#
#     inline = [
#       "curl http://${ibm_is_instance.installer.primary_network_interface[ 0 ].primary_ipv4_address}:7080/prepare/bootstrap | bash",
#       "reboot"
#     ]
#   }
# }
#
#
# resource "null_resource" "master_reboot_to_rhcos" {
#   count = 3
#
#   provisioner "remote-exec" {
#     connection {
#       type                = "ssh"
#       bastion_user        = "root"
#       bastion_private_key = file( var.bastion_key )
#       bastion_host        = module.vpc.bastion_fip
#       host                = ibm_is_instance.master[ count.index ].primary_network_interface[ 0 ].primary_ipv4_address
#       user                = "root"
#       private_key         = file( var.cluster_key )
#     }
#
#     inline = [
#       "curl http://${ibm_is_instance.installer.primary_network_interface[ 0 ].primary_ipv4_address}:7080/prepare/master | bash",
#       "reboot"
#     ]
#   }
# }


# resource "ibm_is_instance" "nameserver" {
#   name           = "nameserver"
#   image          = data.ibm_is_image.ubuntu_1804.id
#   profile        = "bx2-2x8"
#   vpc            = module.vpc.id
#   zone           = module.vpc.vpc_subnet.zone
#   keys           = [ ibm_is_ssh_key.cluster_key.id ]
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
#     private_key         = file( var.cluster_key )
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
#       host-record=etcd-0.${var.cluster_name}.${var.domain_name}.,${local.master_1_pip}
#       host-record=etcd-1.${var.cluster_name}.${var.domain_name}.,${local.master_2_pip}
#       host-record=etcd-2.${var.cluster_name}.${var.domain_name}.,${local.master_3_pip}
#       srv-host=_etcd-server-ssl._tcp.${var.cluster_name}.${var.domain_name}.,etcd-0.${var.cluster_name}.${var.domain_name},2380,0,10
#       srv-host=_etcd-server-ssl._tcp.${var.cluster_name}.${var.domain_name}.,etcd-1.${var.cluster_name}.${var.domain_name},2380,0,10
#       srv-host=_etcd-server-ssl._tcp.${var.cluster_name}.${var.domain_name}.,etcd-2.${var.cluster_name}.${var.domain_name},2380,0,10
#     EOT
#   }
#
#   provisioner "file" {
#     destination = "/etc/dnsmasq.hosts"
#     content = <<-EOT
#       ${ibm_is_instance.installer.primary_network_interface[ 0 ].primary_ipv4_address} installer.${var.cluster_name}.${var.domain_name}          in.${var.cluster_name}.${var.domain_name}
#       ${ibm_is_instance.load_balancer.primary_network_interface[ 0 ].primary_ipv4_address} load-balancer.${var.cluster_name}.${var.domain_name}  lb.${var.cluster_name}.${var.domain_name}
#       ${ibm_is_instance.nameserver.primary_network_interface[ 0 ].primary_ipv4_address} ${ibm_is_instance.nameserver.name}.${var.cluster_name}.${var.domain_name}        ns.${var.cluster_name}.${var.domain_name}
#       ${local.bootstrap_pip} bootstrap.${var.cluster_name}.${var.domain_name}          bs.${var.cluster_name}.${var.domain_name}
#       ${local.master_1_pip} master-1.${var.cluster_name}.${var.domain_name}      m1.${var.cluster_name}.${var.domain_name}
#       ${local.master_2_pip} master-2.${var.cluster_name}.${var.domain_name}      m2.${var.cluster_name}.${var.domain_name}
#       ${local.master_3_pip} master-3.${var.cluster_name}.${var.domain_name}      m3.${var.cluster_name}.${var.domain_name}
#       ${local.worker_1_pip} worker-1.${var.cluster_name}.${var.domain_name}      w1.${var.cluster_name}.${var.domain_name}
#       ${local.worker_2_pip} worker-2.${var.cluster_name}.${var.domain_name}      w2.${var.cluster_name}.${var.domain_name}
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

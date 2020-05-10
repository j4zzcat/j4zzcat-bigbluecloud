variable cluster_name        {}
variable domain_name         {}
variable region_name         {}
variable zone_name           {}
variable data_center_name    {}
variable resource_group_name {}
variable transit_gateway_id  {}
variable bastion_key         {}
variable cluster_key         {}
variable pull_secret         {}

provider "ibm" {
  region     = var.region_name
  generation = 2
}

locals {
  topology_file = "/h/repo/examples/openshift/topology"
}

resource "null_resource" "clean_topology_file" {
  provisioner "local-exec" {
    command = <<-EOT
      rm -f ${local.topology_file}
    EOT
  }
}

### --- VPC ---

data "ibm_resource_group" "resource_group" {
  name = var.resource_group_name
}

module "vpc" {
  source = "/h/repo/lib/terraform/vpc"

  name                = var.cluster_name
  zone_name           = var.zone_name
  classic_access      = false
  dns_service         = true
  dns_domain_name     = var.domain_name
  bastion             = true
  bastion_key         = var.bastion_key
  resource_group_id   = data.ibm_resource_group.resource_group.id
}

resource "null_resource" "transit_gateway_add_connection_vpc" {
  provisioner "local-exec" {
    command = <<-EOT
      ibmcloud login -r ${var.region_name} \
        && ibmcloud tg cc ${var.transit_gateway_id} --name ${var.cluster_name} --network-id ${module.vpc.crn} --network-type vpc
    EOT
  }
}

####
# Cluster Key
#

resource "ibm_is_ssh_key" "cluster_key" {
  name           = "${module.vpc.name}-cluster-key"
  public_key     = file( "${var.cluster_key}.pub" )
  resource_group = data.ibm_resource_group.resource_group.id
}

resource "ibm_compute_ssh_key" "cluster_key" {
  label      = "${var.cluster_name}-cluster-key"
  public_key = file( "${var.cluster_key}.pub" )
  notes      = "owner:j4zzcat"
}

###
# Masters, workers and bootstrap
#

data "ibm_security_group" "allow_all" {
    name = "allow_all"
}

data "ibm_security_group" "allow_outbound" {
    name = "allow_outbound"
}

resource "ibm_compute_vm_instance" "default_gateway" {
  hostname             = "default-gateway"
  domain               = "${var.cluster_name}.${var.domain_name}"
  os_reference_code    = "UBUNTU_18_64"
  datacenter           = var.data_center_name
  hourly_billing       = true
  local_disk           = false
  private_network_only = false
  cores                = 1
  memory               = 1024

  private_security_group_ids = [
    data.ibm_security_group.allow_all.id,
    data.ibm_security_group.allow_outbound.id ]
  public_security_group_ids  = [
    data.ibm_security_group.allow_outbound.id ]

  ssh_key_ids = [
    ibm_compute_ssh_key.cluster_key.id
  ]

  connection {
    type                = "ssh"
    bastion_user        = "root"
    bastion_private_key = file( var.bastion_key )
    bastion_host        = module.vpc.bastion_fip
    host                = self.ipv4_address_private
    user                = "root"
    private_key         = file( var.cluster_key )
  }

  provisioner "remote-exec" {
    inline = [<<-EOT
      yes 'y' | ufw enable
      echo 'net/ipv4/ip_forward=1' >> /etc/ufw/sysctl.conf
      cat <<EOF >>/etc/rc.local
        iptables -P INPUT DROP
        iptables -P FORWARD DROP
        iptables -A INPUT -i lo -j ACCEPT
        iptables -A INPUT -i eth0 -j ACCEPT
        iptables -A INPUT -i eth1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        iptables -A FORWARD -i eth0 -d 10.0.0.0/8 -o eth0 -j ACCEPT
        iptables -A FORWARD -i eth0 -o eth1 -j ACCEPT
        iptables -A FORWARD -i eth1 -o eth0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE
        ufw allow ssh
        exit 0
      EOF
      chmod 755 /etc/rc.local
    EOT
    ]
  }

  provisioner "remote-exec" {
    script = "/h/repo/lib/scripts/ubuntu_18/do_reboot.sh"
  }
}

# iptables -A FORWARD -i eth0 -d ${module.vpc.vpc_subnet.ipv4_cidr_block} -o eth0 -j ACCEPT
# iptables -A FORWARD -i eth0 -d ${module.vpc.bastion_subnet.ipv4_cidr_block} -o eth0 -j ACCEPT

resource "ibm_compute_vm_instance" "bootstrap" {
  hostname             = "bootstrap"
  domain               = "${var.cluster_name}.${var.domain_name}"
  os_reference_code    = "UBUNTU_18_64"
  datacenter           = var.data_center_name
  hourly_billing       = true
  private_network_only = true
  cores                = 1
  memory               = 1024

  private_security_group_ids = [
    data.ibm_security_group.allow_all.id,
    data.ibm_security_group.allow_outbound.id ]

  ssh_key_ids = [
    ibm_compute_ssh_key.cluster_key.id
  ]

  connection {
    type                = "ssh"
    bastion_user        = "root"
    bastion_private_key = file( var.bastion_key )
    bastion_host        = module.vpc.bastion_fip
    host                = self.ipv4_address_private
    user                = "root"
    private_key         = file( var.cluster_key )
  }

  provisioner "remote-exec" {
    inline = [
      "ip route del default",
      "ip route add default via ${ibm_compute_vm_instance.default_gateway.ipv4_address_private} dev eth0"
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
  private_network_only = true
  cores                = 1
  memory               = 1024

  private_security_group_ids = [
    data.ibm_security_group.allow_all.id,
    data.ibm_security_group.allow_outbound.id ]

  ssh_key_ids = [
    ibm_compute_ssh_key.cluster_key.id
  ]

  connection {
    type                = "ssh"
    bastion_user        = "root"
    bastion_private_key = file( var.bastion_key )
    bastion_host        = module.vpc.bastion_fip
    host                = self.ipv4_address_private
    user                = "root"
    private_key         = file( var.cluster_key )
  }

  provisioner "remote-exec" {
    inline = [
      "ip route del default",
      "ip route add default via ${ibm_compute_vm_instance.default_gateway.ipv4_address_private} dev eth0"
    ]
  }
}

resource "ibm_compute_vm_instance" "worker" {
  count = 2

  hostname             = "worker-${count.index + 1}"
  domain               = "${var.cluster_name}.${var.domain_name}"
  os_reference_code    = "UBUNTU_18_64"
  datacenter           = var.data_center_name
  hourly_billing       = true
  private_network_only = true
  cores                = 1
  memory               = 1024

  ssh_key_ids = [
    ibm_compute_ssh_key.cluster_key.id
  ]

  connection {
    type                = "ssh"
    bastion_user        = "root"
    bastion_private_key = file( var.bastion_key )
    bastion_host        = module.vpc.bastion_fip
    host                = self.ipv4_address_private
    user                = "root"
    private_key         = file( var.cluster_key )
  }

  provisioner "remote-exec" {
    inline = [
      "ip route del default",
      "ip route add default via ${ibm_compute_vm_instance.default_gateway.ipv4_address_private} dev eth0"
    ]
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
  bastion_fip         = module.vpc.bastion_fip
  installer_pip       = ibm_is_instance.installer.primary_network_interface[ 0 ].primary_ipv4_address
  load_balancer_pip   = ibm_is_instance.load_balancer.primary_network_interface[ 0 ].primary_ipv4_address
  default_gateway_fip = ibm_compute_vm_instance.default_gateway.ipv4_address
  default_gateway_pip = ibm_compute_vm_instance.default_gateway.ipv4_address_private
  bootstrap_pip       = ibm_compute_vm_instance.bootstrap.ipv4_address_private
  master_1_pip        = ibm_compute_vm_instance.master[ 0 ].ipv4_address_private
  master_2_pip        = ibm_compute_vm_instance.master[ 1 ].ipv4_address_private
  master_3_pip        = ibm_compute_vm_instance.master[ 2 ].ipv4_address_private
  worker_1_pip        = ibm_compute_vm_instance.worker[ 0 ].ipv4_address_private
  worker_2_pip        = ibm_compute_vm_instance.worker[ 1 ].ipv4_address_private
}

resource "local_file" "topology_update_1" {
  filename        = local.topology_file
  file_permission = "0644"
  content = <<-EOT
    bastion_fip         = local.bastion_fip
    installer_pip       = local.installer_pip
    load_balancer_pip   = local.load_balancer_pip
    default_gateway_fip = local.default_gateway_fip
    default_gateway_pip = local.default_gateway_pip
    bootstrap_pip       = local.bootstrap_pip
    master_1_pip        = local.master_1_pip
    master_2_pip        = local.master_2_pip
    master_3_pip        = local.master_3_pip
    worker_1_pip        = local.worker_1_pip
    worker_2_pip        = local.worker_2_pip
  EOT
}

locals {
  hostname_records = {
    "installer.${var.cluster_name}"     = local.installer_pip,
    "load-balancer.${var.cluster_name}" = local.load_balancer_pip,
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

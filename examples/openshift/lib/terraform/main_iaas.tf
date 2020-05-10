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

locals {
  bastion_fip         = "${module.vpc.bastion_fip}"
  default_gateway_fip = "${ibm_compute_vm_instance.default_gateway.ipv4_address}"
  default_gateway_pip = "${ibm_compute_vm_instance.default_gateway.ipv4_address_private}"
  bootstrap_pip       = "${ibm_compute_vm_instance.bootstrap.ipv4_address_private}"
  master_1_pip        = "${ibm_compute_vm_instance.master[ 0 ].ipv4_address_private}"
  master_2_pip        = "${ibm_compute_vm_instance.master[ 1 ].ipv4_address_private}"
  master_3_pip        = "${ibm_compute_vm_instance.master[ 2 ].ipv4_address_private}"
  worker_1_pip        = "${ibm_compute_vm_instance.worker[ 0 ].ipv4_address_private}"
  worker_2_pip        = "${ibm_compute_vm_instance.worker[ 1 ].ipv4_address_private}"
}

resource "local_file" "topology_update_1" {
  filename        = local.topology_file
  file_permission = "0644"
  content = <<-EOT
    bastion_fip         = ${local.bastion_fip}
    default_gateway_fip = ${local.default_gateway_fip}
    default_gateway_pip = ${local.default_gateway_pip}
    bootstrap_pip       = ${local.bootstrap_pip}
    master_1_pip        = ${local.master_1_pip}
    master_2_pip        = ${local.master_2_pip}
    master_3_pip        = ${local.master_3_pip}
    worker_1_pip        = ${local.worker_1_pip}
    worker_2_pip        = ${local.worker_2_pip}
  EOT
}

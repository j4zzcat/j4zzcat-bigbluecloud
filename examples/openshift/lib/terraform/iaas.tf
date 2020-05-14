####
# Cluster Key
#

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

resource "ibm_compute_vm_instance" "nat_server" {
  hostname             = "nat-server"
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
    scripts = [
      "${local.j4zzcat_ubuntu_18_scripts_dir}/upgrade_os.sh",
      "${local.j4zzcat_ubuntu_18_scripts_dir}/install_nat_server.sh",
      "${local.j4zzcat_ubuntu_18_scripts_dir}/do_reboot.sh" ]
  }
}

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
      "ip route add default via ${ibm_compute_vm_instance.nat_server.ipv4_address_private} dev eth0"
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
      "ip route add default via ${ibm_compute_vm_instance.nat_server.ipv4_address_private} dev eth0"
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
      "ip route add default via ${ibm_compute_vm_instance.nat_server.ipv4_address_private} dev eth0"
    ]
  }
}

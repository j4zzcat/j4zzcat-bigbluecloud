provider "ibm" {
  region     = var.region_name
  generation = 2
}

locals {
  repo_dir                      = "/h/repo"

  j4zzcat_dir                   = "${local.repo_dir}/lib"
  j4zzcat_ubuntu_18_scripts_dir = "${local.j4zzcat_dir}/scripts/ubuntu_18"
  j4zzcat_terraform_dir         = "${local.j4zzcat_dir}/terraform"

  openshift_dir                 = "${local.repo_dir}/examples/openshift"
  openshift_scripts_dir         = "${local.openshift_dir}/lib/scripts"
  openshift_helpers_dir         = "${local.openshift_dir}/lib/helpers"
  openshift_terraform_dir       = "${local.openshift_dir}/lib/terraform"

  config_hosts_file             = "${local.openshift_dir}/topology"
}

locals {
  bastion_fip         = module.vpc.bastion_fip
  installer_pip       = ibm_is_instance.installer.primary_network_interface[ 0 ].primary_ipv4_address
  load_balancer_pip   = ibm_is_instance.load_balancer.primary_network_interface[ 0 ].primary_ipv4_address
  nat_server_fip      = ibm_compute_vm_instance.nat_server.ipv4_address
  nat_server_pip      = ibm_compute_vm_instance.nat_server.ipv4_address_private
  bootstrap_pip       = ibm_compute_vm_instance.bootstrap.ipv4_address_private
  master_1_pip        = ibm_compute_vm_instance.master[ 0 ].ipv4_address_private
  master_2_pip        = ibm_compute_vm_instance.master[ 1 ].ipv4_address_private
  master_3_pip        = ibm_compute_vm_instance.master[ 2 ].ipv4_address_private
  worker_1_pip        = ibm_compute_vm_instance.worker[ 0 ].ipv4_address_private
  worker_2_pip        = ibm_compute_vm_instance.worker[ 1 ].ipv4_address_private
}

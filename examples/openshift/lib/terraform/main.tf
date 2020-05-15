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

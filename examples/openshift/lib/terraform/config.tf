resource "null_resource" "rm_hosts_file" {
  provisioner "local-exec" {
    command = <<-EOT
      rm -f ${local.config_hosts_file}
    EOT
  }
}

resource "local_file" "create_hosts_file" {
  filename        = local.config_hosts_file
  file_permission = "0644"
  content = <<-EOT
    bastion_fip       = ${local.bastion_fip}
    installer_pip     = ${local.installer_pip}
    load_balancer_pip = ${local.load_balancer_pip}
    nat_server_fip    = ${local.nat_server_fip}
    nat_server_pip    = ${local.nat_server_pip}
    bootstrap_pip     = ${local.bootstrap_pip}
    master_1_pip      = ${local.master_1_pip}
    master_2_pip      = ${local.master_2_pip}
    master_3_pip      = ${local.master_3_pip}
    worker_1_pip      = ${local.worker_1_pip}
    worker_2_pip      = ${local.worker_2_pip}
  EOT
}

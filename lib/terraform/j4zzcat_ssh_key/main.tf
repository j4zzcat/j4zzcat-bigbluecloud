resource "null_resource" "create_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${var.dir} || true"
  }
}

resource "null_resource" "generate_key" {
  count = length( var.keys )
  provisioner "local-exec" {
    command = <<-EOT
      case "${var.overwrite}" in
        true)  yes 'y' | ssh-keygen -t rsa -b 4096 -N '' -f ${var.dir}/${var.keys[ 0 ]} ;;
        false) yes 'n' | ssh-keygen -t rsa -b 4096 -N '' -f ${var.dir}/${var.keys[ 0 ]} ;;
      esac
    EOT
  }
}

resource "ibm_is_ssh_key" "ssh_key" {
  count = length( var.keys )

  name           = var.keys[ count.index ]
  public_key     = file( "${var.dir}/${var.keys[ count.index ]}.pub" )
  resource_group = var.resource_group_id
}

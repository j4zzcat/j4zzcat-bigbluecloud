resource "ibm_is_ssh_key" "ssh_key" {
  depends_on     = [ null_resource.ssh_key_generate_key ]

  count          = length( var.keys )
  name           = var.keys[ count.index ]
  public_key     = file( "${var.dir}/${var.keys[ count.index ]}.rsa.pub" )
  resource_group = var.resource_group_id
}

resource "null_resource" "ssh_key_generate_key" {
  count = 2
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${var.dir} || true
      case ${var.overwrite} in
        true)  yes 'y' | ssh-keygen -t rsa -b 4096 -N '' -f ${var.dir}/${var.keys[ count.index ]} ;;
        *)     yes 'n' | ssh-keygen -t rsa -b 4096 -N '' -f ${var.dir}/${var.keys[ count.index ]} ;;
      esac
    EOT
  }
}

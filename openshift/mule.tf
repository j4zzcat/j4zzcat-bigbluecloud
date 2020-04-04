# resource "ibm_is_instance" "mule" {
#   depends_on = [ ibm_is_security_group.bootstrap, ibm_is_vpc.vpc_1 ]
#
#   name    = "bootstrap"
# #  image   = "r018-14140f94-fcc4-11e9-96e7-a72723715315"
#   image   = data.ibm_is_instance.ubuntu.id
#   profile = "bx2-2x8"
#   primary_network_interface {
#     name   = "eth0"
#     subnet = ibm_is_subnet.subnet_zone_1.id
#     security_groups = [ ibm_is_security_group.bootstrap.id ]
#   }
#   vpc       = ibm_is_vpc.vpc_1.id
#   zone      = var.vpc_1_zone_1
#   keys      = [ var.admin_ssh_key_id ]
#   user_data = <<-EOT
#     #cloud-config
#     runcmd:
#       - apt update
#       - DEBIAN_FRONTEND=noninteractive apt install -y curl vim mc git ipxe
#       - cloud-init query instance_id
#       - cloud-init query local_hostname
#     EOT
#
#   resource_group = var.resource_group_id
# }

#cloud-config
runcmd:
  - /bin/bash -c "$(curl -fsSL http://172.18.0.11:8070/bootstrap)"






  - /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/j4zzcat/j4zzcat-ibmcloud/master/openshift/bootstrap/bootstrapctl node add --bootstrap-server=1.2.3.4)"













  - apt update
  - DEBIAN_FRONTEND=noninteractive apt install -y curl vim mc git ipxe
  - git clone https://github.com/j4zzcat/j4zzcat-ibmcloud.git /usr/local/src/j4zzcat-ibmcloud
  - /usr/local/src/j4zzcat-ibmcloud/openshift/bootstrap/bootstrapctl node add --instance-id=$(cloud-init query instance_id) --hostname=$(cloud-init query local_hostname) --private-ip=$(hostname -I)



  - sed --in-place -e 's/GRUB_DEFAULT=0/GRUB_DEFAULT=ipxe/' /etc/default/grub
  - sed --in-place -e 's/--class network {/--class network --id ipxe {/' /etc/grub.d/20_ipxe
  - cloud-init query instance_id
  - cloud-init query local_hostname

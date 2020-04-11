# vpc
resource "ibm_is_instance" "l1vs1_network_server" {
  provider       = ibm.l1
  tags           = [ local.fqdn, "l1v", "s1" ]
  resource_group = ibm_is_vpc.l1v_vpc.resource_group


  name       = "network-server-l1vs1"
  image      = data.ibm_is_image.ubuntu_1804.id
  profile    = "bx2-2x8"

  primary_network_interface {
    name     = "eth0"
    subnet   = ibm_is_subnet.l1v_subnet_1.id
    security_groups = [ ibm_is_security_group.any_to_any.id ]
  }

  vpc        = ibm_is_vpc.l1v_vpc.id
  zone       = ibm_is_subnet.l1v_subnet_1.zone
  keys       = [ ibm_is_ssh_key.l1v_admin_ssh_key.id ]
  user_data  = <<-EOT
    #cloud-config
    runcmd:
      - curl -Ls ${local.network_server_post_install_script_url} | bash
    EOT
}

resource "ibm_is_floating_ip" "l1vs1_network_server_fip" {
  provider       = ibm.l1
  tags           = [ local.fqdn, "l1v", "s1" ]
  resource_group = ibm_is_vpc.l1v_vpc.resource_group
  depends_on     = [ ibm_is_instance.l1vs1_network_server ]

  name   = "network-server-l1vs1"
  target = ibm_is_instance.l1vs1_network_server.primary_network_interface[ 0 ].id
}

# iaas
resource "ibm_compute_vm_instance" "l1iv1s1_network_server" {
  provider = ibm.l1
  tags     = [ local.fqdn, "l1i", "v1", "s1" ]

  hostname = "network-server-l1iv1s1"
  domain   = local.fqdn

  os_reference_code       = "UBUNTU_18_64"
  # image_id                = "2354286" # https://cloud.ibm.com/gen1/infrastructure/image-templates/2354286/details#main
  datacenter              = var.l1i_datacenter
  network_speed           = 100
  hourly_billing          = true
  private_network_only    = false
  cores                   = 1
  memory                  = 1024
  disks                   = [ 25 ]
  local_disk              = false
  private_vlan_id         = ibm_network_vlan.l1i_vlan_1.id
  ssh_key_ids             = [ ibm_compute_ssh_key.l1i_admin_ssh_key.id ]
  post_install_script_uri = local.network_server_post_install_script_url
}

resource "ibm_network_interface_sg_attachment" "l1i_sg_network_server" {
  provider = ibm.l1

  security_group_id    = ibm_security_group.l1i_conn_with_l1v.id
  network_interface_id = ibm_compute_vm_instance.l1iv1s1_network_server.public_interface_id
}

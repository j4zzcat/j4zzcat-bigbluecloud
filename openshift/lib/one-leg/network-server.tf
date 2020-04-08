resource "ibm_is_instance" "leg_1_vpc_network_server" {
  provider   = ibm.leg_1
  # depends_on = [ ibm_is_security_group.network_server ]

  name       = "network-server"
  image      = data.ibm_is_image.ubuntu_1804.id
  profile    = "bx2-2x8"

  primary_network_interface {
    name     = "eth0"
    subnet   = ibm_is_subnet.leg_1_vpc_subnet_1.id
    # security_groups = [ ibm_is_security_group.installation_server.id ]
  }

  vpc        = ibm_is_vpc.leg_1_vpc.id
  zone       = ibm_is_subnet.leg_1_vpc_subnet_1.zone
  keys       = [ data.ibm_is_ssh_key.ssh_key.id  ]
  user_data  = <<-EOT
    #cloud-config
    runcmd:
      - curl -Ls | bash
  EOT
}

resource "ibm_compute_vm_instance" "leg_1_iaas_network_server" {
  provider = ibm.leg_1
  hostname = "network-server"
  domain   = var.domain

  os_reference_code    = "UBUNTU_18_04"
  datacenter           = "lon04"
  network_speed        = 100
  hourly_billing       = true
  private_network_only = false
  cores                = 1
  memory               = 1024
  disks                = [25]
  local_disk           = false
}

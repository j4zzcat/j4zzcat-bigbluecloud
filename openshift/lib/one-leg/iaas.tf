resource "ibm_network_vlan" "leg_1_iass_subnet_1" {
  name       = "vlan-1"
  datacenter = var.leg_1_iaas_datacenter
  type       = "PRIVATE"
}

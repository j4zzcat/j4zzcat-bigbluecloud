# --- vlan ---
resource "ibm_network_vlan" "l1i_vlan_1" {
  provider   = ibm.l1
  tags       = [ local.fqdn, "l1i" ]

  name       = join( "-", [ "vlan-1", "l1i", var.name ] )
  datacenter = var.l1i_datacenter
  type       = "PRIVATE"
}

# resource "ibm_subnet" "leg_1_iaas_vlan_1_subnet_1" {
#   type       = "Portable"
#   private    = true
#   ip_version = 4
#   capacity   = 256
#   vlan_id    = ibm_network_vlan.leg_1_iaas_vlan_1.id
# }

resource "ibm_security_group" "l1i_conn_with_l1v" {
  provider = ibm.l1
  tags     = [ local.fqdn ]

  name     = join( "-", [ var.name, "l1i-conn-with-l1v" ] )
}

resource "ibm_security_group_rule" "l1i_conn_with_l1v_inbound" {
  provider = ibm.l1
  tags     = [ local.fqdn ]

  direction         = "ingress"
  ether_type        = "IPv4"
  security_group_id = ibm_security_group.l1i_conn_with_l1v.id
}

resource "ibm_security_group_rule" "l1i_conn_with_l1v_outbound" {
  provider = ibm.l1
  tags     = [ local.fqdn ]

  direction         = "egress"
  ether_type        = "IPv4"
  security_group_id = ibm_security_group.l1i_conn_with_l1v.id
}

# --- ssh key ---
resource "ibm_compute_ssh_key" "l1i_admin_ssh_key" {
  provider   = ibm.l1
  tags       = [ local.fqdn ]

  label = join( "-", [ "admin-ssh-key", var.name, "l1i" ] )
  public_key = file( join( ".", [ var.name, "rsa.pub" ] ) )
}

# --- allow inbound openshift bootstrap ---
resource "ibm_is_security_group" "allow_inbound_openshift_bootstrap" {
  resource_group = var.resource_group_id

  name = "allow-inbound-openshift-bootstrap"
  vpc  = data.ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "tcp_22623_rule" {
  group      = ibm_is_security_group.allow_inbound_openshift_bootstrap.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 22623
    port_max = 22623
  }
}

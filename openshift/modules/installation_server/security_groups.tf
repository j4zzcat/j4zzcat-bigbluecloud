# --- allow inbound TCP 7080 ---
resource "ibm_is_security_group" "allow_inbound_tcp_7080" {
  resource_group = var.resource_group_id

  name = "allow-inbound-tcp-7080"
  vpc  = data.ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "tcp_7080_rule" {
  group      = ibm_is_security_group.allow_inbound_tcp_7080.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 7080
    port_max = 7080
  }
}

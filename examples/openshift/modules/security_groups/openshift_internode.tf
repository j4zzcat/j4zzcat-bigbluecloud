# --- allow openshift internode communication ---
resource "ibm_is_security_group" "allow_inbound_openshift_internode" {
  resource_group = var.resource_group_id

  name = "allow-inbound-openshift-internode"
  vpc  = data.ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "tcp_2379_2380_rule" {
  group      = ibm_is_security_group.allow_inbound_openshift_internode.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 2379
    port_max = 2380
  }
}

resource "ibm_is_security_group_rule" "tcp_6443_rule" {
  group      = ibm_is_security_group.allow_inbound_openshift_internode.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 6443
    port_max = 6443
  }
}

resource "ibm_is_security_group_rule" "tcp_9000_9999_rule" {
  group      = ibm_is_security_group.allow_inbound_openshift_internode.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 9000
    port_max = 9999
  }
}

resource "ibm_is_security_group_rule" "tcp_10249_10259_rule" {
  group      = ibm_is_security_group.allow_inbound_openshift_internode.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 10249
    port_max = 10259
  }
}

resource "ibm_is_security_group_rule" "udp_4789_rule" {
  group      = ibm_is_security_group.allow_inbound_openshift_internode.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  udp {
    port_min = 4789
    port_max = 4789
  }
}

resource "ibm_is_security_group_rule" "udp_6081_rule" {
  group      = ibm_is_security_group.allow_inbound_openshift_internode.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  udp {
    port_min = 6081
    port_max = 6081
  }
}

resource "ibm_is_security_group_rule" "udp_9000_9999_rule" {
  group      = ibm_is_security_group.allow_inbound_openshift_internode.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  udp {
    port_min = 9000
    port_max = 9999
  }
}

resource "ibm_is_security_group_rule" "udp_30000_32767_rule" {
  group      = ibm_is_security_group.allow_inbound_openshift_internode.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  udp {
    port_min = 30000
    port_max = 32767
  }
}

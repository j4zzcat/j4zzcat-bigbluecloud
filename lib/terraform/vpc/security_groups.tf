# --- any_to_any ---
resource "ibm_is_security_group" "allow_any_to_any" {
  resource_group = ibm_is_vpc.vpc.resource_group
  name = "allow-any-to-any"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "allow_outbound_to_any_rule" {
  group      = ibm_is_security_group.allow_any_to_any.id
  direction  = "outbound"
  remote     = "0.0.0.0/0"
}

resource "ibm_is_security_group_rule" "allow_inbound_from_any_rule" {
  group      = ibm_is_security_group.allow_any_to_any.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"
}

# --- allow basic operation ---
resource "ibm_is_security_group" "allow_basic_operation" {
  resource_group = ibm_is_vpc.vpc.resource_group
  name = "allow-basic-operation"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "allow_basic_operation_outbound_to_any_rule" {
  group      = ibm_is_security_group.allow_basic_operation.id
  direction  = "outbound"
  remote     = "0.0.0.0/0"
}

resource "ibm_is_security_group_rule" "allow_basic_operation_icmp_rule" {
  group      = ibm_is_security_group.allow_basic_operation.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  icmp {
    code = 0
    type = 8
  }
}

resource "ibm_is_security_group_rule" "allow_basic_operation_ssh_rule" {
  group      = ibm_is_security_group.allow_basic_operation.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 22
    port_max = 22
  }
}

# --- allow outbound to any ---
resource "ibm_is_security_group" "allow_outbound_any" {
  resource_group = ibm_is_vpc.vpc.resource_group
  name = "allow-outbound-any"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "allow_outbound_to_any_rule_2" {
  group      = ibm_is_security_group.allow_outbound_any.id
  direction  = "outbound"
  remote     = "0.0.0.0/0"
}

# --- allow inbound ping ---
resource "ibm_is_security_group" "allow_inbound_ping" {
  resource_group = ibm_is_vpc.vpc.resource_group
  name = "allow-inbound-ping"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "icmp_rule" {
  group      = ibm_is_security_group.allow_inbound_ping.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  icmp {
    code = 0
    type = 8
  }
}

# --- allow inbound http/https ---
resource "ibm_is_security_group" "allow_inbound_http_https" {
  resource_group = ibm_is_vpc.vpc.resource_group

  name = "allow-inbound-http-https"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "http_rule" {
  group      = ibm_is_security_group.allow_inbound_http_https.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 80
    port_max = 80
  }
}

resource "ibm_is_security_group_rule" "https_rule" {
  group      = ibm_is_security_group.allow_inbound_http_https.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 443
    port_max = 443
  }
}

# --- allow inbound ssh ---
resource "ibm_is_security_group" "allow_inbound_ssh" {
  resource_group = ibm_is_vpc.vpc.resource_group
  name = "allow-inbound-ssh"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "ssh_rule" {
  group      = ibm_is_security_group.allow_inbound_ssh.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 22
    port_max = 22
  }
}

# --- allow inbound dns ---
resource "ibm_is_security_group" "allow_inbound_dns" {
  resource_group = ibm_is_vpc.vpc.resource_group
  name = "allow-inbound-dns"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "dns_tcp_rule" {
  group      = ibm_is_security_group.allow_inbound_dns.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 53
    port_max = 53
  }
}

resource "ibm_is_security_group_rule" "dns_udp_rule" {
  group      = ibm_is_security_group.allow_inbound_dns.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  udp {
    port_min = 53
    port_max = 53
  }
}

# --- allow inbound dhcp ---
resource "ibm_is_security_group" "allow_inbound_dhcp" {
  resource_group = ibm_is_vpc.vpc.resource_group
  name = "allow-inbound-dhcp"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "dhcp_rule" {
  group      = ibm_is_security_group.allow_inbound_dhcp.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  udp {
    port_min = 67
    port_max = 67
  }
}

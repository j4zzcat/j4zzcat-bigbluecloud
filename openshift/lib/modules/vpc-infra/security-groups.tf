# --- any_to_any ---
resource "ibm_is_security_group" "any_to_any" {
  resource_group = ibm_is_vpc.vpc.resource_group
  name = "any-to-any"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "outbound_to_any_rule" {
  group      = ibm_is_security_group.any_to_any.id
  direction  = "outbound"
  remote     = "0.0.0.0/0"
}

resource "ibm_is_security_group_rule" "inbound_from_any_rule" {
  group      = ibm_is_security_group.any_to_any.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"
}

# --- serve ping ---
resource "ibm_is_security_group" "serve_ping" {
  resource_group = ibm_is_vpc.vpc.resource_group
  name = "serve-ping"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "icmp_rule" {
  group      = ibm_is_security_group.serve_ping.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  icmp {
    code = 0
    type = 8
  }
}

# --- serve http/https ---
resource "ibm_is_security_group" "serve_http_https" {
  resource_group = data.ibm_is_vpc.vpc.resource_group

  name = "serve-http-https"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "http_rule" {
  group      = ibm_is_security_group.serve_http_https.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 80
    port_max = 80
  }
}

resource "ibm_is_security_group_rule" "https_rule" {
  group      = ibm_is_security_group.serve_http_https.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 443
    port_max = 443
  }
}

# --- serve ssh ---
resource "ibm_is_security_group" "serve_ssh" {
  resource_group = ibm_is_vpc.vpc.resource_group
  name = "serve-ssh"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "ssh_rule" {
  group      = ibm_is_security_group.serve_ssh.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 22
    port_max = 22
  }
}

# --- serve dns ---
resource "ibm_is_security_group" "serve_dns" {
  resource_group = ibm_is_vpc.vpc.resource_group
  name = "serve-dns"
  vpc  = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "dns_tcp_rule" {
  group      = ibm_is_security_group.serve_dns.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 53
    port_max = 53
  }
}

resource "ibm_is_security_group_rule" "dns_udp_rule" {
  group      = ibm_is_security_group.serve_dns.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  udp {
    port_min = 53
    port_max = 53
  }
}

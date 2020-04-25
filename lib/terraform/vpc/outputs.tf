output "name" {
  value = var.name
}

output "id" {
  value = ibm_is_vpc.vpc.id
}

output "default_subnet" {
  value = ibm_is_subnet.fortress_subnet
}

output "security_groups" {
  value = {
    allow_any_to_any         = ibm_is_security_group.allow_any_to_any.id,
    allow_outbound_any       = ibm_is_security_group.allow_outbound_any.id,
    allow_inbound_ping       = ibm_is_security_group.allow_inbound_ping.id,
    allow_inbound_http_https = ibm_is_security_group.allow_inbound_http_https.id,
    allow_inbound_ssh        = ibm_is_security_group.allow_inbound_ssh.id,
    allow_inbound_dns        = ibm_is_security_group.allow_inbound_dns.id,
    allow_inbound_dhcp       = ibm_is_security_group.allow_inbound_dhcp.id,
    allow_basic_operation    = ibm_is_security_group.allow_basic_operation.id
  }
}

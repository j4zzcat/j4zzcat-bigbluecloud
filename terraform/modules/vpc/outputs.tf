output "id" {
  value = ibm_is_vpc.vpc.id
}

output "default_subnet" {
  value = ibm_is_subnet.default_subnet
}

output "default_admin_key" {
  value = ibm_is_ssh_key.default_admin_key
}

output "standard_security_groups" {
  value = {
    allow_any_to_any         = ibm_is_security_group.allow_any_to_any.id,
    allow_outbound_any       = ibm_is_security_group.allow_outbound_any.id,
    allow_inbound_ping       = ibm_is_security_group.allow_inbound_ping.id,
    allow_inbound_http_https = ibm_is_security_group.allow_inbound_http_https.id,
    allow_inbound_ssh        = ibm_is_security_group.allow_inbound_ssh.id,
    allow_inbound_dns_dhcp   = ibm_is_security_group.allow_inbound_dns_dhcp.id
  }
}

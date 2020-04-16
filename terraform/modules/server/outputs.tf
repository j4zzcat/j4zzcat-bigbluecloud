output "name" {
  value = ibm_is_instance.server.name
}

output "private_ip" {
  value = ibm_is_instance.server.primary_network_interface[ 0 ].primary_ipv4_address
}

output "public_ip" {
  value = ibm_is_floating_ip.server_fip.address
}

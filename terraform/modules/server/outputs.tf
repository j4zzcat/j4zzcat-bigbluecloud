output "private_ip" {
  value = ibm_is_instance.server.primary_network_interface[ 0 ].primary_ipv4_address
}

output "keys" {
  value = ibm_is_ssh_key.ssh_key[ * ]
}

output "ids" {
  value = ibm_is_ssh_key.ssh_key[ * ].id
}

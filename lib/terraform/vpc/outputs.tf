output "name" {
  value = var.name
}

output "id" {
  value = ibm_is_vpc.vpc.id
}

output "fortress_subnet" {
  value = ibm_is_subnet.fortress_subnet
}

output "bastion_subnet" {
  value = var.bastion ? ibm_is_subnet.bastion_subnet : null
}

output "bastion_key" {
  value = var.bastion ? ibm_is_ssh_key.bastion_key[ 0 ].id : null
}

output "bastion_fip" {
  value = var.bastion ? ibm_is_floating_ip.bastion_server_fip[ 0 ].address : null
}

output "security_groups" {
  value = {
    fortress_default = ibm_is_security_group.fortress_default.id,
    bastion_default  = var.bastion ? ibm_is_security_group.bastion_default[ 0 ].id : null
  }
}

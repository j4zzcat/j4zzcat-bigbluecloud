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
    fortress_default = ibm_is_security_group.fortress_default.id,
    bastion_default  = var.bastion ? ibm_is_security_group.bastion_default[ 0 ].id : null
  }
}

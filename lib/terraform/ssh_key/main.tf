locals {
  names = keys( var.keys )
  files = values( var.keys )
}

resource "ibm_is_ssh_key" "ssh_key" {
  count          = length( var.keys )
  name           = local.names[ count.index ]
  public_key     = file( local.files[ count.index ] )
  resource_group = var.resource_group_id
}

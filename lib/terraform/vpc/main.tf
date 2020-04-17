resource "ibm_is_vpc" "vpc" {
  resource_group = var.resource_group_id
  name           = var.name
  classic_access = var.classic_access
}

resource "ibm_is_subnet" "default_subnet" {
  name           = "default-subnet"
  vpc            = ibm_is_vpc.vpc.id
  zone           = var.zone_name
  public_gateway = ibm_is_public_gateway.public_gateway.id
  total_ipv4_address_count = "256"
}

# resource "ibm_is_network_acl" "l1v_conn_with_l1i" {
#   provider = ibm.l1
#
#   name = "l1v-conn-with-l1i"
#   vpc  = ibm_is_vpc.l1v_vpc.id
#
#   rules {
#     name        = "outbound"
#     action      = "allow"
#     source      = "0.0.0.0/0"
#     destination = "0.0.0.0/0"
#     direction   = "outbound"
#   }
#
#   rules {
#     name        = "inbound"
#     action      = "allow"
#     source      = "0.0.0.0/0"
#     destination = "0.0.0.0/0"
#     direction   = "inbound"
#   }
# }

resource "ibm_is_public_gateway" "public_gateway" {
  tags           = null
  resource_group = ibm_is_vpc.vpc.resource_group

  name     = "public-gateway"
  vpc      = ibm_is_vpc.vpc.id
  zone     = var.zone_name
}

# --- ssh key ---
resource "ibm_is_ssh_key" "default_admin_key" {
  tags           = null
  resource_group = ibm_is_vpc.vpc.resource_group

  name       = join( "-", [ var.name, "default-admin-key" ] )
  public_key = file( var.default_admin_key )
}

# ---- cloud object storage ---
# resource "ibm_iam_authorization_policy" "l1v_vpc_image_reader_g_cos" {
#   source_service_name         = "is"
#   source_resource_type        = "image"
#   source_resource_instance_id = ibm_is_vpc.l1v_vpc.id
#
#   target_service_name         = "cloud-object-storage"
#   target_resource_instance_id = ibm_resource_instance.g_cos.id
#   roles                       = [ "Reader" ]
# }
#
# resource "ibm_resource_instance" "g_cos" {
#   provider          = ibm.l1
#   tags              = [ local.fqdn ]
#   resource_group_id = ibm_resource_group.g_resource_group.id
#
#   name              = join( "-", [ var.cluster_name, "cos" ] )
#   service           = "cloud-object-storage"
#   plan              = "standard"
#   location          = "global"
# }

provider "ibm" {
  region     = var.region_name
  generation = 2
}

data "ibm_resource_group" "resource_group" {
  name = var.resource_group_name
}

# ---- Leg 1 VPC ----
resource "ibm_is_vpc" "vpc" {
  tags           = null
  resource_group = data.ibm_resource_group.resource_group.id

  name           = var.vpc_name
  # classic_access = "true"
}

resource "ibm_is_subnet" "subnet_1" {
  name           = "subnet-1"
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
resource "ibm_is_ssh_key" "admin_public_key" {
  tags           = null
  resource_group = ibm_is_vpc.vpc.resource_group

  name       = join( "-", [ var.vpc_name, "admin-key" ] )
  public_key = file( var.admin_public_key )
}

# --- security groups ---
resource "ibm_is_security_group" "any_to_any" {
  resource_group = ibm_is_vpc.vpc.resource_group

  name = "any-to-any"
  vpc  = ibm_is_vpc.vpc.id

}

resource "ibm_is_security_group_rule" "outbound_any_to_any" {
  group      = ibm_is_security_group.any_to_any.id
  direction  = "outbound"
  remote     = "0.0.0.0/0"
}

resource "ibm_is_security_group_rule" "inbound_any_to_any" {
  group      = ibm_is_security_group.any_to_any.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"
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

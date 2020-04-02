
resource "ibm_is_vpc" "vpc_1" {
  name           = var.vpc_1
  classic_access = "true"
  resource_group = var.resource_group_id
}

resource "ibm_is_subnet" "subnet_1" {
  name                     = "subnet-1"
  vpc                      = ibm_is_vpc.vpc_1.id
  zone                     = var.vpc_1_zone
  total_ipv4_address_count = "128"
}

resource "ibm_is_public_gateway" "public_gateway_1" {
  name = "public-gateway-1"
  vpc  = ibm_is_vpc.vpc_1.id
  zone = var.vpc_1_zone
}

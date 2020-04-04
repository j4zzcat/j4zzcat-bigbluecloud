
resource "ibm_is_vpc" "vpc_1" {
  name           = join( "-", [ var.cluster_name, var.vpc_1 ] )
  classic_access = "true"
  resource_group = var.resource_group_id
}

resource "ibm_is_subnet" "subnet_zone_1" {
  name                     = "subnet-zone-1"
  vpc                      = ibm_is_vpc.vpc_1.id
  zone                     = var.vpc_1_zone_1
  total_ipv4_address_count = "256"
}

resource "ibm_is_public_gateway" "public_gateway_zone_1" {
  name = "public-gateway-zone-1"
  vpc  = ibm_is_vpc.vpc_1.id
  zone = var.vpc_1_zone_1

  resource_group = var.resource_group_id
}

resource "ibm_is_subnet" "subnet_zone_2" {
  name                     = "subnet-zone-2"
  vpc                      = ibm_is_vpc.vpc_1.id
  zone                     = var.vpc_1_zone_2
  total_ipv4_address_count = "256"
}

resource "ibm_is_public_gateway" "public_gateway_zone_2" {
  name = "public-gateway-zone-2"
  vpc  = ibm_is_vpc.vpc_1.id
  zone = var.vpc_1_zone_2

  resource_group = var.resource_group_id
}

resource "ibm_resource_instance" "cos" {
  name              = join( "-", [ var.cluster_name, "cos" ] )
  service           = "cloud-object-storage"
  plan              = "standard"
  location          = "global"
  
  resource_group_id = var.resource_group_id
}

resource "ibm_iam_authorization_policy" "is_image_reader_cos" {
  source_service_name         = "is"
  source_resource_type        = "image"
  source_resource_instance_id = ibm_is_vpc.vpc_1.id

  target_service_name         = "cloud-object-storage"
  target_resource_instance_id = ibm_resource_instance.cos.id
  roles                       = [ "Reader" ]
}

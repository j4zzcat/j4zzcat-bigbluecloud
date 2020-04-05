variable ibmcloud_api_key {}
variable resource_group   {}
variable cluster_name     {}
variable leg_1_vpc        {}
variable leg_1_region     {}
variable leg_1_zone       {}
# variable leg_2_region     {}
# variable leg_2_zone       {}
# variable leg_3_region     {}
# variable leg_3_zone       {}

provider "ibm" {
  alias            = "leg_1"
  ibmcloud_api_key = var.ibmcloud_api_key
  generation       = 2
  region           = var.leg_1_region
}

data "ibm_resource_group" "RESOURCE_GROUP" {
  name = var.resource_group
}

# ---- Leg 1 ----
resource "ibm_is_vpc" "leg_1_vpc" {
  provider       = ibm.leg_1
  name           = var.cluster_name
  classic_access = "true"
  resource_group = data.ibm_resource_group.RESOURCE_GROUP.id
}

resource "ibm_is_subnet" "leg_1_subnet_1" {
  provider = ibm.leg_1
  name     = "subnet-1"
  vpc      = ibm_is_vpc.leg_1_vpc.id
  zone     = var.leg_1_zone
  total_ipv4_address_count = "256"
}

resource "ibm_is_public_gateway" "public_gateway" {
  provider = ibm.leg_1
  name     = "public-gateway"
  vpc      = ibm_is_vpc.leg_1_vpc.id
  zone     = var.leg_1_zone

  resource_group = ibm_is_vpc.leg_1_vpc.resource_group
}

resource "ibm_iam_authorization_policy" "is_image_reader_cos" {
  source_service_name         = "is"
  source_resource_type        = "image"
  source_resource_instance_id = ibm_is_vpc.leg_1_vpc.id

  target_service_name         = "cloud-object-storage"
  target_resource_instance_id = ibm_resource_instance.cos.id
  roles                       = [ "Reader" ]
}

# ---- Global resources ----
resource "ibm_resource_instance" "cos" {
  provider          = ibm.leg_1
  name              = join( "-", [ var.cluster_name, "cos" ] )
  service           = "cloud-object-storage"
  plan              = "standard"
  location          = "global"

  resource_group_id = data.ibm_resource_group.RESOURCE_GROUP.id
}

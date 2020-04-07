variable ibmcloud_api_key {}

variable resource_group   {}
variable ssh_key          {}

variable cluster          {}
variable leg_1_vpc        {}
variable leg_1_region     {}
variable leg_1_zone       {}

provider "ibm" {
  alias            = "leg_1"
  ibmcloud_api_key = var.ibmcloud_api_key
  generation       = 2
  region           = var.leg_1_region
}

# provider "ibm" {
#   alias            = "leg_2"
#   ibmcloud_api_key = var.ibmcloud_api_key
#   generation       = 2
#   region           = var.leg_2_region
# }
#
# provider "ibm" {
#   alias            = "leg_3"
#   ibmcloud_api_key = var.ibmcloud_api_key
#   generation       = 2
#   region           = var.leg_3_region
# }

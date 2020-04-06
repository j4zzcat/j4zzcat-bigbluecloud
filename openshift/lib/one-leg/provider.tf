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

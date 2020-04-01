variable apikey    {}
provider "ibm" {
  ibmcloud_api_key = var.apikey
  generation       = 2
  region           = var.region
}

variable zone {
  default = "eu-gb-3"
}

variable vpc    {
  default = "r018-401e9412-4876-4e07-a7ac-3a728a4f4554"
}
variable subnet {
  default = "07a7-99294ef3-5740-4a3f-8f9e-ffe697ed679f"
}

variable key {
  default = "r018-86c889ed-497e-4fa5-836e-8ae6895aad82"
}

resource "ibm_is_vpc" "testbed" {
  name = "testbed"
}


# # ubuntu-18.04-minimal-amd64
# resource "ibm_is_instance" "xxx" {
#   name    = "yyy"
#   image   = "r018-14140f94-fcc4-11e9-96e7-a72723715315"
#   profile = "bx2-2x8"
#
#   primary_network_interface {
#     subnet = var.subnet
#   }
#
#   vpc       = var.vpc
#   zone      = var.zone
#   keys      = [ var.key ]
#   user_data = file( "image-server.ci" )
# }

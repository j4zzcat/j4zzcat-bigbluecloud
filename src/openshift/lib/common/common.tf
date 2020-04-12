
variable cluster_name   {}
variable cluster_domain {}
variable l1v_region     {}
variable l1v_zone       {}
# variable l1i_datacenter {}

#
# These are read from the environment and used
# in the provider
#
# provider key           env variable
# -------------------------------------------------
# ibmcloud_api_key       IC_API_KEY
# iaas_classic_username  IAAS_CLASSIC_USERNAME
# iaas_classic_api_key   IAAS_CLASSIC_API_KEY
# iaas_classic_timeout   IAAS_CLASSIC_TIMEOUT
#
provider "ibm" {
  alias      = "l1"
  region     = var.l1v_region
  generation = 2
}

# local variables
locals {
  fqdn           = join( ".", [ var.cluster_name, var.cluster_domain ] )
  resource_group = join( "_", [ var.cluster_name, var.cluster_domain ] )
  l1v_vpc        = join( "-", [ var.cluster_name, "l1v" ] )
}

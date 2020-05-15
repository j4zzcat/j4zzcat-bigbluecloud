variable cluster_name        {}
variable domain_name         {}
variable bastion_key         {}
variable cluster_key         {}
variable pull_secret         {}

# Optional, map to existing resources
variable region_name         {
  default = "us-south"
}

variable zone_name {
  default "us-south-2"
}

variable data_center_name {
  default = "ldal10"
}

variable resource_group_name {
  default = null
}

variable dns_service_name {
  default = null
}

variable transit_gateway_id {
  default = null
}

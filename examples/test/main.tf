variable cluster_name        {}
variable domain_name         {}
variable region_name         {}
variable zone_name           {}
variable resource_group_name {}
variable bastion_key         {}
variable cluster_key         {}
variable pull_secret         {}

locals {
  vpc_name      = var.cluster_name
  repo_home     = "https://github.com/j4zzcat/j4zzcat-ibmcloud"
  repo_home_raw = "https://raw.githubusercontent.com/j4zzcat/j4zzcat-ibmcloud/master"
  vpc_key       = var.cluster_key
  iaas_key      = var.cluster_key
  hosts_file    = "./hosts"
}

provider "ibm" {
  region     = var.region_name
  generation = 2
}

data "ibm_resource_group" "resource_group" {
  name = var.resource_group_name
}

resource "ibm_resource_instance" "dns_service" {
  name              = "${var.name}-dns-service"
  service           = "dns-svcs"
  plan              = "standard-dns"
  location          = "global"
  resource_group_id = var.resource_group_id
}

resource "ibm_dns_zone" "vpc" {
    name        = var.domain_name
    instance_id = ibm_resource_instance.dns_service.guid
}

resource "ibm_dns_permitted_network" "vpc" {
    instance_id = ibm_resource_instance.dns_service.guid
    zone_id     = ibm_dns_zone.default.zone_id
    vpc_crn     = ibm_is_vpc.vpc.crn
    type        = "vpc"
}

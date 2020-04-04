variable ibmcloud_api_key    {}
variable admin_ssh_key_id    {}
variable resource_group_id   {}

variable cluster_name        {}

variable vpc_1               {}
variable vpc_1_region        {}
variable vpc_1_zone_1        {}
variable vpc_1_zone_2        {}

variable vpc_2               {}
variable vpc_2_region        {}
variable vpc_2_zone_1        {}
variable vpc_2_zone_2        {}

data ibm_is_image "ubuntu_1804" {
  name = "ibm-ubuntu-18-04-64"
}

resource_group = "rusty"
ssh_key        = "imac-key"

cluster               = "peto"
domain                = "rusty.ibmcloud"
leg_1_vpc             = "${var.cluster}-leg-1"
leg_1_vpc_region      = "eu-gb"
leg_1_vpc_zone        = "eu-gb-1"
leg_1_iaas_datacenter = "lon02"

# internal
installation_server_post_install_script = "https://raw.githubusercontent.com/j4zzcat/j4zzcat-ibmcloud/0.2/openshift/lib/scripts/installation-server-post-install.sh"
network_server_post_install_script      = "https://raw.githubusercontent.com/j4zzcat/j4zzcat-ibmcloud/0.2/openshift/lib/scripts/network-server-post-install.sh"

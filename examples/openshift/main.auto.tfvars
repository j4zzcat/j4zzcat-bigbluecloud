# required
cluster_name        = "blackfish"
domain_name         = "blue.cloud"
region_name         = "us-south"
zone_name           = "us-south-2"
cluster_key         = "./keys/cluster-key.rsa"
bastion_key         = "./keys/bastion-key.rsa"
pull_secret         = "./keys/pull-secret.txt"
resource_group_name = "ibm/j4zzcat"

# optional
infra_profile       = "bx2-2x8"
masters_profile     = "bx2-2x8"
workers_profile     = "bx2-2x8"

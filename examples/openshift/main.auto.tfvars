# required
cluster_name        = "blackfish"
domain_name         = "cloud"
region_name         = "eu-gb"
zone_name           = "eu-gb-3"
cluster_key         = "./keys/cluster-key.rsa"
bastion_key         = "./keys/bastion-key.rsa"
pull_secret         = "./keys/pull-secret.txt"
resource_group_name = "peto"

# optional
infra_profile       = "bx2-2x8"
masters_profile     = "bx2-2x8"
workers_profile     = "bx2-2x8"

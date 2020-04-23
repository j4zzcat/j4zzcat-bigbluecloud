# Required
cluster_name        = "rover"
domain_name         = "local"
region_name         = "eu-gb"
zone_name           = "eu-gb-1"
resource_group_name = "peto"
admin_key           = "./keys/admin-key.rsa"
bastion_key         = "./keys/bastion-key.rsa"
pull_secret         = "./keys/pull-secret.txt"

infra_profile       = "bx2-2x8"
masters_profile     = "bx2-2x8"
workers_profile     = "bx2-2x8"


bastion_fip=$(terraform state show module.vpc.ibm_is_floating_ip.bastion_server_fip[0] | awk -F '"' '/address/{print $2}')
bastion_key=
installer_ip=$(terraform state show ibm_is_instance.installer | awk -F '"' '/primary_ipv4_address/{print $2}')

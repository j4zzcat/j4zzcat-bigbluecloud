output "openshift_security_groups" {
  value = {
    allow_inbound_openshift_bootstrap = ibm_is_security_group.allow_inbound_openshift_bootstrap.id,
    allow_inbound_openshift_internode = ibm_is_security_group.allow_inbound_openshift_internode.id
  }
}

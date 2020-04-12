General
- Consistent naming across resources and terraform local resources
  resource-peto             g_local_resource
  resource-peto-l1vs1       l1vs1_local_resource
  resource-peto-l1iv1s1     l1iv1s1_local_resource

Security
- generate ssh key and load it to l1v and l1i
  assign the ssh key to all compute instances  
- On l1v create acl to restrict communication only to l1i_vlan_1 (connetcion-with-peto-l1i)
- On l1i create security group to restrict communication only to l1v_vpc (connection-with-peto-l1v)

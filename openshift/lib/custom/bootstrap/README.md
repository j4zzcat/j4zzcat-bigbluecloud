#cloud-config
runcmd:
  - /bin/bash -c "$(curl -fsSL http://172.18.0.11:8070/bootstrap)"
    /bin/bash -c "$(curl -fsSL http://158.175.188.19:8070/bootstrap)"

# /etc/hosts
127.0.0.1       localhost

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost   ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
172.18.0.11     bootstrap-server  bootstrap-server.rusty.ibmcloud
172.18.0.14     mule4             mule4.rusty.ibmcloud
172.18.0.15     mule5             mule5.rusty.ibmcloud

# /etc/dnsmasq.conf
port=53
domain-needed
bogus-priv
strict-order
expand-hosts
domain=rusty.ibmcloud
no-resolv
local=/rusty.ibmcloud/
conf-file=/etc/dhcp.conf

# /etc/dhcp.conf
dhcp-range=172.18.0.11,172.18.0.240,255.255.255.0,24h
dhcp-option=option:router,172.18.0.1
dhcp-option=option:dns-server,172.18.0.11
dhcp-option=option:netmask,255.255.255.0

dhcp-host=mule4,172.18.0.14
dhcp-host=mule5,172.18.0.15
dhcp-host=mule6,172.18.0.16
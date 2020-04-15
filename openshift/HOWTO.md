### DNS
* See the status of dns services: `systemd-resolve --status`
# Restart name resolution: `systemctl restart systemd-resolved`
* DHCP with manual nameserver: https://askubuntu.com/questions/1001241/can-netplan-configured-nameservers-supersede-not-merge-with-the-dhcp-nameserve
* Search domain: https://askubuntu.com/questions/584054/how-do-i-configure-the-search-domain-correctly
* Netplan examples: https://netplan.io/examples
* Minimum dnsmasq.conf:
```
port=53
log-queries
domain-needed
bogus-priv
expand-hosts
local=/peto/
domain=peto
```

### Terraform
* Show available instances:  terraform state list
* Show state of instance: terraform state show module.haproxy_masters.module.haproxy_server.ibm_is_instance.server

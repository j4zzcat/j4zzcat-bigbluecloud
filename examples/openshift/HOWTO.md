### DNS
* See the status of dns services: `systemd-resolve --status`
* Restart name resolution: `systemctl restart systemd-resolved`
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

### Bastion
ssh -o ProxyCommand="ssh -W %h:%p -i keys/bastion-key.rsa root@<bastion_fip>" -i keys/bastion-key.rsa root@<server_in_fortress>

### Terraform
* Show available instances:  `terraform state list`
* Show state of instance:
  ```
  terraform state show module.haproxy_masters.module.haproxy_server.ibm_is_instance.server
  ```

* Get public ip:
  ```
  terraform state show module.network_server.module.network_server.ibm_is_floating_ip.server_fip \
    | awk '/address/{print $3}' \
    | awk -F '"' '{print $2}'
  ```

* Get private ip:
  ```
  terraform state show module.master_1.module.master_1.ibm_is_instance.server \
    | awk '/primary_ipv4_address/{print $3}' \
    | awk -F '"' '{print $2}'
  ```

### OpenShift
* install-config.yaml
  sed -e "s/\(pullSecret:\).*/\1 '"$(cat pull-secret.txt)"'/" install-config.yaml

* Login to a RHCOS instance via:
  `ssh -i /opt/openshift/install/openshift-key.rsa core@IP`

* Watch the status with:
  `journalctl -b -f -u bootkube.service`

### Classic infra
* Create server
* Assign 'allow_all' and 'allow_outbound' to the private interface

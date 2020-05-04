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

### IAAS Public gateway
Enable firewall
```
ufw enable
```

Enable forwarding
```
echo 'net/ipv4/ip_forward=1' >> /etc/ufw/sysctl.conf
```

Firewall rules
```
touch /etc/rc.local
chmod 755 /etc/rc.local
cat <<EOT >>/etc/rc.local
  # Assuming that private interface is 'eth0' and public is 'eth1'

  # Default policy to drop all incoming packets.
  iptables -P INPUT DROP
  iptables -P FORWARD DROP

  # Accept incoming packets from localhost and the LAN interface.
  iptables -A INPUT -i lo -j ACCEPT
  iptables -A INPUT -i eth0 -j ACCEPT

  # Accept incoming packets from the WAN if the router initiated the connection.
  iptables -A INPUT -i eth1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

  # Forward LAN packets to the WAN.
  iptables -A FORWARD -i eth0 -o eth1 -j ACCEPT

  # Forward WAN packets to the LAN if the LAN initiated the connection.
  iptables -A FORWARD -i eth1 -o eth0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

  # NAT traffic going out the WAN interface.
  iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE

  exit 0
EOT
```

On the client:
```
ip route del default
ip route add default via <ip of public gateway> dev eth0
```

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

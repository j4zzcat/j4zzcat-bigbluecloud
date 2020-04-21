# enable manual nameserver with dhcp
echo 'UseDNS=false' >> /run/systemd/network/10-netplan-ens3.network

# disable cloud init netplan generation
echo 'network: {config: disabled}' > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg

# add nameserver to the netplan
sed --in-place \
  -e 's/\(\s*\)\(dhcp4: true\)/\1\2\n\1nameservers:\n\1    search: ['${domain_name}']\n\1    addresses: ['${nameserver_ip}']/' \
  /etc/netplan/50-cloud-init.yaml

netplan apply

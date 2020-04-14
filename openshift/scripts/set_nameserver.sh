local nameserver=${1}

# enable manual nameserver with dhcp
echo 'UseDNS=false' >> /run/systemd/network/10-netplan-ens3.network

# disable cloud init netplan generation
echo 'network: {config: disabled}' > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg

# add nameserver to the netplan

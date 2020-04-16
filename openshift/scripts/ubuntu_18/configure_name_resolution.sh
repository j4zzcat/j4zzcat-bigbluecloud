NAMESERVER=${1}
DOMAIN=${2}

# enable manual nameserver with dhcp
echo 'UseDNS=false' >> /run/systemd/network/10-netplan-ens3.network

# disable cloud init netplan generation
echo 'network: {config: disabled}' > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg

# add nameserver to the netplan
sed --in-place \
  -e 's/\(\s*\)\(dhcp4: true\)/\1\2\n\1nameservers:\n\1    search: ['${DOMAIN}']\n\1    addresses: ['${NAMESERVER}']/' \
  /etc/netplan/50-cloud-init.yaml

netplan apply

# register my ip and hostname with the dns
# timeout 5m bash -c 'while :; do ping -c 1 '${NAMESERVER}' && break; done'
# MY_IP=$(hostname -I)
# MY_HOSTNAME=$(hostname)
# curl -X POST \
#   --data "hostname=${MY_HOSTNAME}" \
#   http://${NAMESERVER}:7080/registar/${MY_IP}

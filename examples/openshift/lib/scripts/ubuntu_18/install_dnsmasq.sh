CLUSTER_NAME=${1}
DOMAIN_NAME=${2}

# install and configure dnsmasq
systemctl stop systemd-resolved
systemctl disable systemd-resolved
rm /etc/resolv.conf
echo -e "nameserver 161.26.0.10\nnameserver 161.26.0.11" > /etc/resolv.conf

DEBIAN_FRONTEND=noninteractive apt install -y \
  dnsmasq

cat <<EOT >/etc/dnsmasq.conf
port=53
no-hosts
addn-hosts=/etc/dnsmasq.hosts.${DOMAIN_NAME}
log-queries
domain-needed
bogus-priv
expand-hosts
local=/${DOMAIN_NAME}/
domain=${DOMAIN_NAME}
EOT
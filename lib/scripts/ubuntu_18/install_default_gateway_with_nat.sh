#!/usr/bin/env bash

echo "install_default_gateway_with_nat.sh is starting..."

ufw enable
echo 'net/ipv4/ip_forward=1' >> /etc/ufw/sysctl.conf

touch /etc/rc.local
chmod 755 /etc/rc.local
cat <<EOT >>/etc/rc.local
  iptables -P INPUT DROP
  iptables -P FORWARD DROP
  iptables -A INPUT -i lo -j ACCEPT
  iptables -A INPUT -i eth0 -j ACCEPT
  iptables -A INPUT -i eth1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A FORWARD -i eth0 -d 10.0.0.0/8 -o eth0 -j ACCEPT
  iptables -A FORWARD -i eth0 -o eth1 -j ACCEPT
  iptables -A FORWARD -i eth1 -o eth0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE
  exit 0
EOT

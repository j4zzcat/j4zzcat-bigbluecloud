#!/usr/bin/env bash

echo "install_nat_server.sh is starting..."

DEBIAN_FRONTEND=noninteractive apt-get install -qq -y iptables-persistent netfilter-persistent

yes 'y' | ufw enable
echo 'net/ipv4/ip_forward=1' >> /etc/ufw/sysctl.conf
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -i eth0 -j ACCEPT
iptables -A INPUT -i eth1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i eth0 -d 10.0.0.0/8 -o eth0 -j ACCEPT

# iptables -A FORWARD -i eth0 -d ${module.vpc.vpc_subnet.ipv4_cidr_block} -o eth0 -j ACCEPT
# iptables -A FORWARD -i eth0 -d ${module.vpc.bastion_subnet.ipv4_cidr_block} -o eth0 -j ACCEPT

iptables -A FORWARD -i eth0 -o eth1 -j ACCEPT
iptables -A FORWARD -i eth1 -o eth0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE
ufw allow ssh

iptables-save > /etc/iptables/rules.v4
netfilter-persistent save
netfilter-persistent start
systemctl restart netfilter-persistent
systemctl enable ufw

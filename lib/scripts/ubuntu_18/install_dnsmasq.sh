#!/usr/bin/env bash

echo "install_dnsmasq.sh is starting..."

# install and configure dnsmasq for IBM Cloud
systemctl stop systemd-resolved
systemctl disable systemd-resolved
rm /etc/resolv.conf

# use the ibm cloud nameservers for upstream
echo -e "nameserver 161.26.0.10\nnameserver 161.26.0.11" > /etc/resolv.conf

DEBIAN_FRONTEND=noninteractive apt install -y \
  dnsmasq

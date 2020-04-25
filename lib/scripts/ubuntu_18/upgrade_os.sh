#!/usr/bin/env bash

echo "Upgrading OS to the latest level..."
apt update -q

rm /boot/grub/menu.lst
ucf --purge /var/run/grub/menu.lst
update-grub-legacy-ec2 -y
ucf --purge /etc/ssh/sshd_config

DEBIAN_FRONTEND=noninteractive apt-get \
  -o Dpkg::Options::=--force-confnew \
  -o Dpkg::Options::=--force-confdef \
  --allow-downgrades \
  --allow-remove-essential \
  --allow-change-held-packages \
  -qq -y dist-upgrade

echo "Installing basic software..."
DEBIAN_FRONTEND=noninteractive apt-get \
  install -qq -y \
    mc vim

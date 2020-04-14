# install and configure dnsmasq
systemctl stop systemd-resolved
systemctl disable systemd-resolved
rm /etc/resolv.conf
echo -e "nameserver 161.26.0.10\nnameserver 161.26.0.11" > /etc/resolv.conf
apt install -y dnsmasq

Client
- install ipxe
- fix ipxe in /etc/grub.d/20_ipxe
  sed --in-place -e 's/\(--class network\) {/\1 --id ipxe {/' /etc/grub.d/20_ipxe
  sed --in-place -e 's/\(GRUB_DEFAULT\)=0/\1=ipxe/' /etc/default/grub

- configure ipxe boot
  for VPC VS:
  sed --in-place -e 's|\(linux16.*\)|\1 dhcp \\\&\\\& chain http://172.18.0.4:8070/boot?hostname=BLAH|' /etc/grub.d/20_ipxe

  for Classic Baremetal since there's no DHCP available (?)
  sed --in-place -e 's|\(linux16.*\)|\1 ifopen net0 \\\&\\\& set net0/ip BLAH \\\&\\\& set net0/netmask BLAH \\\&\\\& set net0/gateway BLAH \\\&\\\& chain http://172.18.0.4:8070/boot?hostname=BLAH|' /etc/grub.d/20_ipxe

  update-grub



On the Client
#cloud-config
runcmd:
  - /bin/bash -c "$(curl -fsSL http://172.18.0.11:8070/bootstrap)"
    /bin/bash -c "$(curl -fsSL http://158.175.188.19:8070/bootstrap)"

On the DNS Server
Remove self entry
# /etc/hosts
127.0.0.1       localhost

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost   ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
172.18.0.11     bootstrap-server  bootstrap-server.rusty.ibmcloud
172.18.0.14     mule4             mule4.rusty.ibmcloud
172.18.0.15     mule5             mule5.rusty.ibmcloud

# /etc/dnsmasq.conf
port=53
#domain-needed
bogus-priv
strict-order
expand-hosts
domain=rusty.ibmcloud
no-resolv
local=/rusty.ibmcloud/

<!-- conf-file=/etc/dhcp.conf
dhcp-range=172.18.0.11,172.18.0.240,255.255.255.0,24h
dhcp-option=option:router,172.18.0.1
dhcp-option=option:dns-server,172.18.0.11
dhcp-option=option:netmask,255.255.255.0

dhcp-host=mule4,172.18.0.14
dhcp-host=mule5,172.18.0.15
dhcp-host=mule6,172.18.0.16 -->

/etc/netplan/50-cloud-init.yaml
# This file is generated from information provided by
# the datasource.  Changes to it will not persist across an instance.
# To disable cloud-init's network configuration capabilities, write a file
# /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg with the following:
# network: {config: disabled}
network:
    version: 2
    ethernets:
        ens3:
            dhcp4: true
            dhcp4-overrides:
                use-dns: no
            match:
                macaddress: 02:00:02:01:53:56
            set-name: ens3
            nameservers:
                addresses: [172.18.0.4]

https://askubuntu.com/questions/1001241/can-netplan-configured-nameservers-supersede-not-merge-with-the-dhcp-nameserve
#  /run/systemd/network/10-netplan-ens3.network
[Match]
MACAddress=02:00:02:01:53:56
Name=ens3

[Network]
DHCP=ipv4
LinkLocalAddressing=ipv6
DNS=172.18.0.4

[DHCP]
UseMTU=true
RouteMetric=100
UseDNS=false

# ipxe script
#!ipxe
dhcp
set base http://mirror.centos.org/centos/7/os/x86_64
kernel ${base}/images/pxeboot/vmlinuz initrd=initrd.img repo=${base}
initrd ${base}/images/pxeboot/initrd.img
boot


# bare metal script
script = <<~EOT
  #!ipxe
  ifopen net0
  set net0/ip 10.72.220.203
  set net0/netmask 255.255.255.192
  set net0/gateway 10.72.220.193
  set base http://mirror.centos.org/centos/7/os/x86_64
  kernel ${base}/images/pxeboot/vmlinuz initrd=initrd.img repo=${base}
  initrd ${base}/images/pxeboot/initrd.img
  boot
EOT

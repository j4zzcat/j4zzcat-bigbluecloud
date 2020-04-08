resource "ibm_is_instance" "leg_1_vpc_network_server" {
  provider   = ibm.leg_1
  # depends_on = [ ibm_is_security_group.network_server ]

  name       = "network-server"
  image      = data.ibm_is_image.ubuntu_1804.id
  profile    = "bx2-2x8"

  primary_network_interface {
    name     = "eth0"
    subnet   = ibm_is_subnet.leg_1_vpc_subnet_1.id
    # security_groups = [ ibm_is_security_group.installation_server.id ]
  }

  vpc        = ibm_is_vpc.leg_1_vpc.id
  zone       = ibm_is_subnet.leg_1_vpc_subnet_1.zone
  keys       = [ data.ibm_is_ssh_key.ssh_key.id  ]
  user_data  = <<-EOT
    #cloud-config
    runcmd:
      - curl -Ls b| bash
      - rm /boot/grub/menu.lst; ucf --purge /var/run/grub/menu.lst; update-grub-legacy-ec2 -y
      - ucf --purge /etc/ssh/sshd_config
      - DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::=--force-confnew -o Dpkg::Options::=--force-confdef --allow-downgrades --allow-remove-essential --allow-change-held-packages -y dist-upgrade
      - DEBIAN_FRONTEND=noninteractive apt install -y ruby2.5-dev apache2 gcc g++ make binutils liblzma-dev mtools mkisofs syslinux isolinux xorriso qemu-kvm
      - gem install --no-document bundle sinatra thin
      - mkdir -p /var/network-server/images
      - cd /var/network-server/images; for file in installer-kernel-x86_64 installer-initramfs.x86_64.img installer.x86_64.iso metal.x86_64.raw.gz; do curl -LO https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.3/4.3.8/rhcos-4.3.8-x86_64-${file}; done
      - systemctl stop systemd-resolved; systemctl disable systemd-resolved; rm /etc/resolv.conf; echo -e "nameserver 161.26.0.10\nnameserver 161.26.0.11" > /etc/resolv.conf
      - apt install -y dnsmasq
  EOT
}

resource "ibm_compute_vm_instance" "leg_1_iaas_network_server" {
  provider = ibm.leg_1
  hostname = "network-server"
  domain   = var.domain

  os_reference_code    = "UBUNTU_18_04"
  datacenter           = "lon04"
  network_speed        = 100
  hourly_billing       = true
  private_network_only = false
  cores                = 1
  memory               = 1024
  disks                = [25]
  local_disk           = false
}

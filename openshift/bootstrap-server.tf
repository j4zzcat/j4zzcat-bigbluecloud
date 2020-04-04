
resource "ibm_is_security_group" "bootstrap" {
  name = "bootstrap"
  vpc  = ibm_is_vpc.vpc_1.id

  resource_group = var.resource_group_id
}

resource "ibm_is_security_group_rule" "outbound_rule" {
  depends_on = [ ibm_is_security_group.bootstrap ]

  group      = ibm_is_security_group.bootstrap.id
  direction  = "outbound"
  remote     = "0.0.0.0/0"
}

resource "ibm_is_security_group_rule" "ssh_rule" {
  depends_on = [ ibm_is_security_group.bootstrap ]

  group      = ibm_is_security_group.bootstrap.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "icmp_rule" {
  depends_on = [ ibm_is_security_group.bootstrap ]

  group      = ibm_is_security_group.bootstrap.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  icmp {
    code = 0
    type = 8
  }
}

resource "ibm_is_security_group_rule" "http_rule" {
  depends_on = [ ibm_is_security_group.bootstrap ]

  group      = ibm_is_security_group.bootstrap.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 80
    port_max = 80
  }
}

resource "ibm_is_instance" "bootstrap" {
  depends_on = [ ibm_is_security_group.bootstrap, ibm_is_vpc.vpc_1 ]

  name    = "bootstrap"
  image   = data.ibm_is_image.ubuntu_1804.id
  profile = "bx2-2x8"
  primary_network_interface {
    name   = "eth0"
    subnet = ibm_is_subnet.subnet_zone_1.id
    security_groups = [ ibm_is_security_group.bootstrap.id ]
  }
  vpc       = ibm_is_vpc.vpc_1.id
  zone      = var.vpc_1_zone_1
  keys      = [ var.admin_ssh_key_id ]
  user_data = <<-EOT
    #cloud-config
    runcmd:
      - apt update
      - rm /boot/grub/menu.lst; ucf --purge /var/run/grub/menu.lst; update-grub-legacy-ec2 -y
      - ucf --purge /etc/ssh/sshd_config
      - DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::=--force-confnew -o Dpkg::Options::=--force-confdef --allow-downgrades --allow-remove-essential --allow-change-held-packages -y dist-upgrade
      - DEBIAN_FRONTEND=noninteractive apt install -y curl vim mc git python3 python3-pip ruby apache2 apt-utils apt-transport-https ca-certificates software-properties-common
      - DEBIAN_FRONTEND=noninteractive apt install -y gcc g++ make binutils liblzma-dev mtools mkisofs syslinux isolinux xorriso qemu-kvm
      - curl -L -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.12.24/terraform_0.12.24_linux_amd64.zip; unzip /tmp/terraform.zip -d /tmp; mv /tmp/terraform /usr/local/bin
      - curl -L -o /tmp/ibmcloud_terraform.zip https://github.com/IBM-Cloud/terraform-provider-ibm/releases/download/v1.2.5/linux_amd64.zip; unzip /tmp/ibmcloud_terraform.zip -d /tmp; mkdir -p ~/.terraform.d/plugins; mv /tmp/terraform-provider-ibm* ~/.terraform.d/plugins
      - gem install --no-document sinatra
      - mkdir -p /usr/local/src; git clone https://github.com/ipxe/ipxe /usr/local/src/ipxe; cd /usr/local/src/ipxe/src; make
      - curl -sL https://ibm.biz/idt-installer | bash; echo 'source /usr/local/ibmcloud/autocomplete/bash_autocomplete' >> /root/.bashrc
      - cd /root; echo 'vpc-infrastructure dns cloud-object-storage kp tke vpn' | xargs -n 1 ibmcloud plugin install

    power_state:
      delay: "+10"
      mode: reboot
      timeout: 10
      condition: True
    EOT

  resource_group = var.resource_group_id
}

resource "ibm_is_floating_ip" "bootstrap" {
  depends_on = [ ibm_is_instance.bootstrap ]

  name   = "bootstrap"
  target = ibm_is_instance.bootstrap.primary_network_interface[ 0 ].id

  resource_group = var.resource_group_id
}

resource "ibm_cos_bucket" "bootstrap" {
  bucket_name          = join( "-", [ ibm_resource_instance.cos.name, "bootstrap" ] )
  resource_instance_id = ibm_resource_instance.cos.id
  region_location      = var.vpc_1_region
  storage_class        = "standard"
}

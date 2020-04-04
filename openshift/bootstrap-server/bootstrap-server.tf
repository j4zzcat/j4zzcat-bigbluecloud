variable ibmcloud_api_key {}
variable ssh_key          {}
variable region           {}
variable vpc              {}
variable subnet_id        {}

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  generation       = 2
  region           = var.region
}

data "ibm_is_vpc" "vpc" {
  name = var.vpc
}

data "ibm_is_ssh_key" "ssh_key" {
  name = var.ssh_key
}

data "ibm_is_subnet" "subnet" {
  identifier = var.subnet_id
}

data "ibm_is_image" "ubuntu_1804" {
  name = "ibm-ubuntu-18-04-64"
}

resource "ibm_is_security_group" "bootstrap_server" {
  name = "bootstrap-server"
  vpc  = data.ibm_is_vpc.vpc.id

  resource_group = data.ibm_is_vpc.vpc.resource_group
}

resource "ibm_is_security_group_rule" "outbound_rule" {
  depends_on = [ ibm_is_security_group.bootstrap_server ]

  group      = ibm_is_security_group.bootstrap_server.id
  direction  = "outbound"
  remote     = "0.0.0.0/0"
}

resource "ibm_is_security_group_rule" "ssh_rule" {
  depends_on = [ ibm_is_security_group.bootstrap_server ]

  group      = ibm_is_security_group.bootstrap_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "icmp_rule" {
  depends_on = [ ibm_is_security_group.bootstrap_server ]

  group      = ibm_is_security_group.bootstrap_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  icmp {
    code = 0
    type = 8
  }
}

resource "ibm_is_security_group_rule" "http_rule" {
  depends_on = [ ibm_is_security_group.bootstrap_server ]

  group      = ibm_is_security_group.bootstrap_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 80
    port_max = 80
  }
}

resource "ibm_is_security_group_rule" "sinatra_rule" {
  depends_on = [ ibm_is_security_group.bootstrap_server ]

  group      = ibm_is_security_group.bootstrap_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 8070
    port_max = 8070
  }
}

resource "ibm_is_instance" "bootstrap_server" {
  depends_on = [ ibm_is_security_group.bootstrap_server ]

  name    = "bootstrap-server"
  image   = data.ibm_is_image.ubuntu_1804.id
  profile = "bx2-2x8"
  primary_network_interface {
    name   = "eth0"
    subnet = data.ibm_is_subnet.subnet.id
    security_groups = [ ibm_is_security_group.bootstrap_server.id ]
  }
  vpc       = data.ibm_is_vpc.vpc.id
  zone      = data.ibm_is_subnet.subnet.zone
  keys      = [ data.ibm_is_ssh_key.ssh_key.id  ]
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
      - mkdir -p /usr/local/src; git clone https://github.com/ipxe/ipxe /usr/local/src/ipxe; cd /usr/local/src/ipxe/src; make
      - curl -sL https://ibm.biz/idt-installer | bash; echo 'source /usr/local/ibmcloud/autocomplete/bash_autocomplete' >> /root/.bashrc
      - cd /root; echo 'vpc-infrastructure dns cloud-object-storage kp tke vpn' | xargs -n 1 ibmcloud plugin install
      - gem install --no-document bundle sinatra
      - git clone https://github.com/j4zzcat/j4zzcat-ibmcloud /usr/local/src/j4zzcat-ibmcloud

    power_state:
      mode: reboot
      timeout: 1
      condition: True
    EOT

  resource_group = data.ibm_is_vpc.vpc.resource_group
}

resource "ibm_is_floating_ip" "bootstrap_server" {
  depends_on = [ ibm_is_instance.bootstrap_server ]

  name   = "bootstrap-server"
  target = ibm_is_instance.bootstrap_server.primary_network_interface[ 0 ].id

  resource_group = data.ibm_is_vpc.vpc.resource_group
}

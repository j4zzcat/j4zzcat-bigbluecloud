data "ibm_is_ssh_key" "ssh_key" {
  provider = ibm.leg_1

  name = var.ssh_key
}

data "ibm_is_image" "ubuntu_1804" {
  name = "ibm-ubuntu-18-04-64"
}

resource "ibm_is_security_group" "installation_server" {
  provider = ibm.leg_1

  name = "installation-server"
  vpc  = ibm_is_vpc.leg_1_vpc.id

  resource_group = ibm_is_vpc.leg_1_vpc.resource_group
}

# TODO harden
resource "ibm_is_security_group_rule" "outbound_rule" {
  provider   = ibm.leg_1

  group      = ibm_is_security_group.installation_server.id
  direction  = "outbound"
  remote     = "0.0.0.0/0"
}

resource "ibm_is_security_group_rule" "ssh_rule" {
  provider   = ibm.leg_1

  group      = ibm_is_security_group.installation_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "icmp_rule" {
  provider   = ibm.leg_1

  group      = ibm_is_security_group.installation_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  icmp {
    code = 0
    type = 8
  }
}

resource "ibm_is_security_group_rule" "dns_rule" {
  provider   = ibm.leg_1

  group      = ibm_is_security_group.installation_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 53
    port_max = 53
  }
}

resource "ibm_is_security_group_rule" "dhcp_rule" {
  provider   = ibm.leg_1

  group      = ibm_is_security_group.installation_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  udp {
    port_min = 67
    port_max = 67
  }
}

resource "ibm_is_security_group_rule" "http_rule" {
  provider   = ibm.leg_1
  group      = ibm_is_security_group.installation_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 80
    port_max = 80
  }
}

resource "ibm_is_security_group_rule" "sinatra_rule" {
  provider   = ibm.leg_1

  group      = ibm_is_security_group.installation_server.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"

  tcp {
    port_min = 8070
    port_max = 8070
  }
}

resource "ibm_is_instance" "leg_1_vpc_installation_server" {
  provider   = ibm.leg_1
  depends_on = [ ibm_is_security_group.installation_server ]

  name       = "installation-server"
  image      = data.ibm_is_image.ubuntu_1804.id
  profile    = "bx2-2x8"
  primary_network_interface {
    name     = "eth0"
    subnet   = ibm_is_subnet.leg_1_vpc_subnet_1.id
    security_groups = [ ibm_is_security_group.installation_server.id ]
  }
  vpc        = ibm_is_vpc.leg_1_vpc.id
  zone       = ibm_is_subnet.leg_1_vpc_subnet_1.zone
  keys       = [ data.ibm_is_ssh_key.ssh_key.id  ]
  user_data  = <<-EOT
    #cloud-config
    runcmd:
      - apt update
      - rm /boot/grub/menu.lst; ucf --purge /var/run/grub/menu.lst; update-grub-legacy-ec2 -y
      - ucf --purge /etc/ssh/sshd_config
      - DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::=--force-confnew -o Dpkg::Options::=--force-confdef --allow-downgrades --allow-remove-essential --allow-change-held-packages -y dist-upgrade
      - DEBIAN_FRONTEND=noninteractive apt install -y curl vim mc git python3 python3-pip ruby2.5-dev apache2 apt-utils apt-transport-https ca-certificates software-properties-common
      - DEBIAN_FRONTEND=noninteractive apt install -y gcc g++ make binutils liblzma-dev mtools mkisofs syslinux isolinux xorriso qemu-kvm
      - curl -Lo /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.12.24/terraform_0.12.24_linux_amd64.zip; unzip /tmp/terraform.zip -d /tmp; mv /tmp/terraform /usr/local/bin
      - curl -Lo /tmp/ibmcloud_terraform.zip https://github.com/IBM-Cloud/terraform-provider-ibm/releases/download/v1.2.5/linux_amd64.zip; unzip /tmp/ibmcloud_terraform.zip -d /tmp; mkdir -p ~/.terraform.d/plugins; mv /tmp/terraform-provider-ibm* ~/.terraform.d/plugins
      - mkdir -p /usr/local/src; git clone https://github.com/ipxe/ipxe /usr/local/src/ipxe; cd /usr/local/src/ipxe/src; make
      - curl -sL https://ibm.biz/idt-installer | bash; echo 'source /usr/local/ibmcloud/autocomplete/bash_autocomplete' >> /root/.bashrc
      - cd /root; echo 'vpc-infrastructure dns cloud-object-storage kp tke vpn' | xargs -n 1 ibmcloud plugin install
      - gem install --no-document bundle sinatra thin
      - git clone https://github.com/j4zzcat/j4zzcat-ibmcloud /usr/local/src/j4zzcat-ibmcloud
      - cd /tmp; curl -LO wget https://mirrors.mit.edu/ubuntu-cdimage/releases/19.10/release/ubuntu-19.10-server-amd64.iso
      - mkdir -p /opt/openshift; cd /opt/openshift
      - curl -Lo /tmp/openshift-install.tgz https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-install-linux-4.3.9.tar.gz; tar -xzvf /tmp/openshift-install.tgz
      - curl -Lo /tmp/openshift-client.tgz https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz; tar -xzvf /tmp/openshift-client.tgz
      - ssh-keygen -t rsa -b 4096 -N '' -f /opt/openshift/rsa_id

    power_state:
      mode: reboot
      timeout: 1
      condition: True
    EOT

  resource_group = ibm_is_vpc.leg_1_vpc.resource_group
}

resource "ibm_is_floating_ip" "installation" {
  provider   = ibm.leg_1
  depends_on = [ ibm_is_instance.leg_1_vpc_installation_server ]

  name   = "installation-server"
  target = ibm_is_instance.installation_server.primary_network_interface[ 0 ].id

  resource_group = ibm_is_vpc.leg_1_vpc.resource_group
}
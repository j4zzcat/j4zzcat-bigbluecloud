
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
  image   = "r018-14140f94-fcc4-11e9-96e7-a72723715315"
  profile = "bx2-2x8"
  primary_network_interface {
    name   = "eth0"
    subnet = ibm_is_subnet.subnet_1.id
    security_groups = [ ibm_is_security_group.bootstrap.id ]
  }
  vpc       = ibm_is_vpc.vpc_1.id
  zone      = var.vpc_1_zone
  keys      = [ var.admin_ssh_key_id ]
  user_data = <<-EOT
    #cloud-config
    runcmd:
      - apt update
      - DEBIAN_FRONTEND=noninteractive apt install -y curl vim mc git python3 python3-pip ruby apache2 apt-utils apt-transport-https ca-certificates software-properties-common
      - DEBIAN_FRONTEND=noninteractive apt install -y gcc g++ make binutils liblzma-dev mtools mkisofs syslinux isolinux xorriso qemu-kvm
      - curl -L -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.12.24/terraform_0.12.24_linux_amd64.zip; unzip /tmp/terraform.zip -d /tmp; mv /tmp/terraform /usr/local/bin
      - curl -L -o /tmp/ibmcloud_terraform.zip https://github.com/IBM-Cloud/terraform-provider-ibm/releases/download/v1.2.5/linux_amd64.zip; unzip /tmp/ibmcloud_terraform.zip -d /tmp; mkdir -p ~/.terraform.d/plugins; mv /tmp/terraform-provider-ibm* ~/.terraform.d/plugins
      - gem install --no-document sinatra
      - mkdir -p /usr/local/src; git clone https://github.com/ipxe/ipxe /usr/local/src/ipxe; cd /usr/local/src/ipxe/src; make
      - curl -sL https://ibm.biz/idt-installer | bash; ibmcloud plugin install vpc-infrastructure
    EOT

  resource_group = var.resource_group_id
}

resource "ibm_is_floating_ip" "bootstrap" {
  depends_on = [ ibm_is_instance.bootstrap ]

  name   = "bootstrap"
  target = ibm_is_instance.bootstrap.primary_network_interface[ 0 ].id

  resource_group = var.resource_group_id
}

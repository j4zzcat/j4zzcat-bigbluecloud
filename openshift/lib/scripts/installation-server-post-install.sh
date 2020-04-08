# proper upgrade
apt update

rm /boot/grub/menu.lst
ucf --purge /var/run/grub/menu.lst
update-grub-legacy-ec2 -y
ucf --purge /etc/ssh/sshd_config

DEBIAN_FRONTEND=noninteractive
apt-get \
  -o Dpkg::Options::=--force-confnew \
  -o Dpkg::Options::=--force-confdef \
  --allow-downgrades \
  --allow-remove-essential \
  --allow-change-held-packages -y \
  dist-upgrade

# terraform
cd /tmp
curl -LO https://releases.hashicorp.com/terraform/0.12.24/terraform_0.12.24_linux_amd64.zip
unzip /tmp/terraform*.zip -d /tmp
mv /tmp/terraform /usr/local/bin

# ibmcloud terraform provider
cd /tmp
curl -LO https://github.com/IBM-Cloud/terraform-provider-ibm/releases/download/v1.2.5/linux_amd64.zip
unzip /tmp/linux_amd64.zip -d /tmp
mkdir -p ~/.terraform.d/plugins
mv /tmp/terraform-provider-ibm* ~/.terraform.d/plugins

# ibmcloud cli
cd /root
curl -sL https://ibm.biz/idt-installer | bash
echo 'source /usr/local/ibmcloud/autocomplete/bash_autocomplete' >> /root/.bashrc
echo 'vpc-infrastructure dns cloud-object-storage kp tke vpn' | xargs -n 1 ibmcloud plugin install

# openshift
cd /tmp
curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-install-linux-4.3.9.tar.gz
curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
mkdir -p /opt/openshift
cd /opt/openshift
tar -xzvf /tmp/openshift-install*.tgz
tar -xzvf /tmp/openshift-client*.tgz

# ssh-keygen -t rsa -b 4096 -N '' -f /opt/openshift/rsa_id

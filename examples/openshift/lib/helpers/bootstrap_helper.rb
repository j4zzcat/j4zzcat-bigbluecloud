require 'sinatra/base'
require 'ipaddress'

HELPER_IP         = IPAddress::IPv4.new( %x[ hostname -I ].strip )
HELPER_PORT       = '7080'
HELPER_DNS        = %x[ systemd-resolve --status | tail | awk -F ':' '/DNS Servers/{print $2}'].strip
HELPER_DOMAIN     = %x[ systemd-resolve --status | tail | awk -F ':' '/DNS Domain/{print $2}'].strip
HELPER_STATE_DIR  = '.'
HELPER_REGISTAR   = "#{HELPER_STATE_DIR}/bootstrap_helper.registar"
HELPER_PUBLIC_DIR = '/var/sinatra/www'

OPENSHIFT_CLUSTER_NAME = %x[ cat /opt/openshift/etc/main.auto.tfvars | awk -F '"' '/cluster_name.*=/{print $2}' ].chomp
OPENSHIFT_WWW          = "http://#{HELPER_IP}:#{HELPER_PORT}/openshift"

class BootstrapServer
  def run
    Rack::Server.start( {
      server: 'thin',
      Host:   '0.0.0.0',
      Port:   HELPER_PORT,
      app: Rack::Builder.app do
        map '/' do
          run WebApp.new
        end
      end
    } )
  end # run

  private

  class WebApp < Sinatra::Base
    configure do
      enable :logging
      set    :public_folder, HELPER_PUBLIC_DIR
    end

    get '/netmask_of' do
      net_address = params[ 'net_address' ]
      IPAddress::IPv4.new( net_address ).netmask
    end

    get '/prepare/:openshift_node_type' do
      client_ip           = request.ip
      openshift_node_type = params[ 'openshift_node_type' ]

      probe = <<~EOT
        instance_id=$(cloud-init query instance_id)
        net_hostname=$(hostname)
        net_address=$(ip addr | grep -e 'inet ' | grep #{client_ip} | awk '{print $2}')
        net_netmask=$(curl -X GET \
                        --data "net_address=${net_address}" \
                        http://#{HELPER_IP}:#{HELPER_PORT}/netmask_of)
        net_ip=$(echo ${net_address} | awk -F '/' '{print $1}')
        net_gateway=$(ip route show default | awk '/#{client_ip}/{print $3}')
        curl -X POST \
          --data "net_hostname=${net_hostname}" \
          --data "net_ip=${net_ip}" \
          --data "net_netmask=${net_netmask}" \
          --data "net_gateway=${net_gateway}" \
          --data "openshift_node_type=#{openshift_node_type}" \
          http://#{HELPER_IP}:#{HELPER_PORT}/register/${instance_id}
      EOT

      install_ipxe = <<~EOT
        apt update
        apt install -y ipxe
        sed --in-place -e 's/GRUB_DEFAULT=0/GRUB_DEFAULT=ipxe/' /etc/default/grub
        sed --in-place -e 's/--class network {/--class network --id ipxe {/' /etc/grub.d/20_ipxe
      EOT

      prepare_grub = <<~EOT
        sed --in-place -e 's|linux16.*|linux16 $IPXEPATH ifopen net0 \\\\\\&\\\\\\& set net0/ip #{client_ip} \\\\\\&\\\\\\& set net0/netmask '${net_netmask}' \\\\\\&\\\\\\& set net0/gateway '${net_gateway}' \\\\\\&\\\\\\& chain http://#{HELPER_IP.to_s}:#{HELPER_PORT}/boot/'${instance_id}'|' /etc/grub.d/20_ipxe
        update-grub
        # reboot
      EOT

      return "#{probe}\n#{install_ipxe}\n#{prepare_grub}"
    end

    post '/register/:instance_id' do
      instance_id         = params[ 'instance_id' ]
      net_hostname        = params[ 'net_hostname' ]
      net_fqhn            = "#{net_hostname}.#{OPENSHIFT_CLUSTER_NAME}.#{HELPER_DOMAIN}"
      net_ip              = params[ 'net_ip' ]
      net_netmask         = params[ 'net_netmask' ]
      net_gateway         = params[ 'net_gateway' ]
      openshift_node_type = params[ 'openshift_node_type' ]

      record = "#{instance_id} #{net_fqhn} #{net_ip} #{net_netmask} #{net_gateway} #{openshift_node_type}"
      %x[ sed --in-place -e '/^#{instance_id} .*/d' #{HELPER_REGISTAR} ] if File.exist? HELPER_REGISTAR
      %x[ echo "#{record}" >> #{HELPER_REGISTAR} ]
    end

    get '/boot/:instance_id' do
      instance_id = params[ 'instance_id' ]
      pk, net_fqhn, net_ip, net_netmask, net_gateway, openshift_node_type = %x[ cat #{HELPER_REGISTAR} | grep -e '^#{instance_id}' ].chomp.split

      configure_ip = <<~EOT
        ifopen net0
        set net0/ip #{net_ip}
        set net0/netmask #{net_netmask}
        set net0/gateway #{net_gateway}
      EOT

      # ip=#{net_ip}::#{net_gateway}:#{net_netmask}:#{net_fqhn} nameserver=#{HELPER_DNS}
      kernel = <<~EOT
        kernel #{OPENSHIFT_WWW}/rhcos/rhcos-4.3.8-x86_64-installer-kernel-x86_64 \
          initrd=#{OPENSHIFT_WWW}/rhcos/rhcos-4.3.8-x86_64-installer-initramfs.x86_64.img \
          coreos.inst=yes \
          coreos.inst.install_dev=sda \
          coreos.inst.image_url=#{OPENSHIFT_WWW}/rhcos/rhcos-4.3.8-x86_64-metal.x86_64.raw.gz \
          coreos.inst.ignition_url=#{OPENSHIFT_WWW}/install/#{openshift_node_type}.ign \
          rd.neednet=1 console=tty0 console=ttyS0 \
          ip=#{net_ip}::#{net_gateway}:#{net_netmask}:#{net_fqhn}:ens3:none nameserver=#{HELPER_DNS}
      EOT

      initrd = <<~EOT
        initrd #{OPENSHIFT_WWW}/rhcos/rhcos-4.3.8-x86_64-installer-initramfs.x86_64.img
      EOT

      return <<~EOT
        #!ipxe
        #{configure_ip}
        #{kernel}
        #{initrd}
        boot
      EOT
    end

  end
end

BootstrapServer.new.run

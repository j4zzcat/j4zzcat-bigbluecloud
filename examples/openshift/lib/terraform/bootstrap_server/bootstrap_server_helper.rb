require 'sinatra/base'
require 'ipaddress'

MY_IP      = IPAddress::IPv4.new( %x[ hostname -I ].strip )
MY_PORT    = '7080'
MY_SUBNET  = IPAddress::IPv4.new( %x[ ip addr | grep $(hostname -I) | awk '{print $2}' ].strip ).network
MY_NETMASK = MY_SUBNET.netmask
MY_GATEWAY = %x[ ip route show default | awk '/#{MY_IP.to_s}/{print $3}' ].chomp
MY_DOMAIN  = %x[ systemd-resolve --status | awk -F ':' '/DNS Domain/{print $2}'].strip

class BootstrapServer
  def run
    Rack::Server.start( {
      server: 'thin',
      Host:   '0.0.0.0',
      Port:   MY_PORT,
      app: Rack::Builder.app do
        map '/' do
          run WebApp.new
        end
      end
    } )
  end # run

  private

  def get_ip( fqhn )
    %x[ dig #{fqhn} | awk '/^#{fqhn}/{ print $5 }' ].chomp
  end

  def get_node_type( fqhn )
    if fqhn.start_with "bootstrap"
      :bootstrap
    elsif fqhn.start_with "master"
      :master
    elsif fqhn.start_with "worker"
      :worker
    else
      :unknown
    end
  end

  class WebApp < Sinatra::Base
    configure do
      enable :logging
    end

    get '/prepare/:type/:ip' do
      client_type = params[ 'type' ]
      cilent_ip   = params[ 'ip' ]

      return <<~EOT
        apt update
        apt install -y ipxe
        sed --in-place -e 's/GRUB_DEFAULT=0/GRUB_DEFAULT=ipxe/' /etc/default/grub
        sed --in-place -e 's/--class network {/--class network --id ipxe {/' /etc/grub.d/20_ipxe
        sed --in-place -e 's|linux16.*|linux16 $IPXEPATH dhcp \\\\&\\\\& chain http://#{MY_IP.to_s}:#{MY_PORT}/boot/#{client_type}/#{client_ip}|' /etc/grub.d/20_ipxe
        update-grub
        # reboot
      EOT
    end

    get '/boot/:type/:ip' do
      fqhn    = params[ 'fqhn' ]
      ip      = get_ip( fqhn )
      type    = get_node_type( fqhn )

      kernel_cmd = <<~EOT
        kernel http://#{MY_IP}/openshift/rhcos/rhcos-4.3.8-x86_64-installer-kernel-x86_64 \
          coreos.inst=yes \
          coreos.inst.install_dev=sda \
          coreos.inst.image_url=http://#{MY_IP}/openshift/rhcos/metal.x86_64.raw.gz \
          coreos.inst.ignition_url=http://#{MY_IP}/openshift/install/coppermine.dollar/#{type.to_s}_config.ign \
          ip=#{ip}::#{settings.my_gateway}:#{settings.my_netmask}:#{fqhn} nameserver=#{settings.my_nameserver}
      EOT

      initrd_cmd = <<~EOT
        http://#{MY_IP}/openshift/rhcos/rhcos-4.3.8-x86_64-installer-initramfs.x86_64.img
      EOT

      return <<~EOT
        #!ipxe
        dhcp
        route
        #{kernel_cmd}
        #{initrd_cmd}
        boot
      EOT
    end

  end
end

BootstrapServer.new.run

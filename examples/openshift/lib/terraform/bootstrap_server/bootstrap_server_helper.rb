require 'sinatra/base'
require 'ipaddress'

MY_IP      = IPAddress::IPv4.new( %x[ hostname -I ].strip )
MY_PORT    = '7080'
MY_SUBNET  = IPAddress::IPv4.new( %x[ ip addr | grep $(hostname -I) | awk '{print $2}' ].strip ).network
MY_NETMASK = MY_SUBNET.netmask
MY_GATEWAY = %x[ ip route show default | awk '/#{MY_IP.to_s}/{print $3}' ].chomp
MY_DNS     = %x[ systemd-resolve --status | tail | awk -F ':' '/DNS Servers/{print $2}'].strip
MY_DOMAIN  = %x[ systemd-resolve --status | tail | awk -F ':' '/DNS Domain/{print $2}'].strip

OPENSHIFT_CLUSTER_NAME = %x[ ls -l /opt/openshift/install | awk '/#{MY_DOMAIN}/{print $9}' | awk -F '.' '{print $1}' ]

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

  class WebApp < Sinatra::Base
    configure do
      enable :logging
    end

    get '/prepare/:type' do
      client_type = params[ 'type' ]

      return <<~EOT
        apt update
        apt install -y ipxe
        sed --in-place -e 's/GRUB_DEFAULT=0/GRUB_DEFAULT=ipxe/' /etc/default/grub
        sed --in-place -e 's/--class network {/--class network --id ipxe {/' /etc/grub.d/20_ipxe
        sed --in-place -e 's|linux16.*|linux16 $IPXEPATH dhcp \\\\\\&\\\\\\& chain http://#{MY_IP.to_s}:#{MY_PORT}/boot/#{client_type}|' /etc/grub.d/20_ipxe
        update-grub
        # reboot
      EOT
    end

    get '/boot/:type' do
      client_type = params[ 'type' ]
      client_ip   = request.ip
      client_fqhn = %x[ nslookup #{client_ip} | head -n 1 | awk -F '=' '{print $2}' ].strip[ 0..-2 ]

      kernel_cmd = <<~EOT
        kernel http://#{MY_IP}/openshift/rhcos/rhcos-4.3.8-x86_64-installer-kernel-x86_64 \
          coreos.inst=yes \
          coreos.inst.install_dev=sda \
          coreos.inst.image_url=http://#{MY_IP}/openshift/rhcos/metal.x86_64.raw.gz \
          coreos.inst.ignition_url=http://#{MY_IP}/openshift/install/#{OPENSHIFT_CLUSTER_NAME}.#{MY_DOMAIN}/#{client_type.to_s}_config.ign \
          ip=#{client_ip}::#{MY_GATEWAY}:#{MY_NETMASK}:#{client_fqhn} nameserver=#{MY_DNS}
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

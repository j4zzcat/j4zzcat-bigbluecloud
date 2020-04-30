require 'sinatra/base'
require 'ipaddress'

HELPER_IP      = IPAddress::IPv4.new( %x[ hostname -I ].strip )
HELPER_PORT    = '7080'
HELPER_SUBNET  = IPAddress::IPv4.new( %x[ ip addr | grep $(hostname -I) | awk '{print $2}' ].strip ).network
HELPER_NETMASK = HELPER_SUBNET.netmask
HELPER_GATEWAY = %x[ ip route show default | awk '/#{HELPER_IP.to_s}/{print $3}' ].chomp
HELPER_DNS     = %x[ systemd-resolve --status | tail | awk -F ':' '/DNS Servers/{print $2}'].strip
HELPER_DOMAIN  = %x[ systemd-resolve --status | tail | awk -F ':' '/DNS Domain/{print $2}'].strip

# OPENSHIFT_CLUSTER_NAME = %x[ ls -l /opt/openshift/install | awk '/#{HELPER_DOMAIN}/{print $9}' | awk -F '.' '{print $1}' ]
OPENSHIFT_CLUSTER_NAME = 'rover'

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
      set :public_folder, '/var/sinatra/www'
    end

    get '/prepare/:device_type/:openshift_server_type' do
      device_type           = params[ 'device_type' ]
      openshift_server_type = params[ 'openshift_server_type' ]
      client_ip             = request.ip

      case device_type
      when 'm'
      when 'vp'
      when 'vt'
        return <<~EOT
          apt update
          apt install -y ipxe
          export CLIENT_GATEWAY=$(ip route show default | awk '{print $3}')
          sed --in-place -e 's/GRUB_DEFAULT=0/GRUB_DEFAULT=ipxe/' /etc/default/grub
          sed --in-place -e 's/--class network {/--class network --id ipxe {/' /etc/grub.d/20_ipxe
          sed --in-place -e 's|linux16.*|linux16 $IPXEPATH ifopen net0 \\\\\\&\\\\\\& set net0/ip #{client_ip} \\\\\\&\\\\\\& set net0/gateway '${CLIENT_GATEWAY}' \\\\\\&\\\\\\& chain http://#{HELPER_IP.to_s}:#{HELPER_PORT}/boot/#{openshift_server_type}|' /etc/grub.d/20_ipxe
          update-grub
          # reboot
        EOT
      when 'is'
      end
    end

    get '/boot/:type' do
      client_type = params[ 'type' ]
      client_ip   = request.ip
      client_fqhn = %x[ nslookup #{client_ip} | head -n 1 | awk -F '=' '{print $2}' ].strip[ 0..-2 ]

      kernel_cmd = <<~EOT
        kernel http://#{HELPER_IP}/openshift/rhcos/rhcos-4.3.8-x86_64-installer-kernel-x86_64 \
          coreos.inst=yes \
          coreos.inst.install_dev=sda \
          coreos.inst.image_url=http://#{HELPER_IP}/openshift/rhcos/metal.x86_64.raw.gz \
          coreos.inst.ignition_url=http://#{HELPER_IP}/openshift/install/#{OPENSHIFT_CLUSTER_NAME}.#{HELPER_DOMAIN}/#{client_type.to_s}_config.ign \
          ip=#{client_ip}::#{HELPER_GATEWAY}:#{HELPER_NETMASK}:#{client_fqhn} nameserver=#{HELPER_DNS}
      EOT

      initrd_cmd = <<~EOT
        http://#{HELPER_IP}/openshift/rhcos/rhcos-4.3.8-x86_64-installer-initramfs.x86_64.img
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
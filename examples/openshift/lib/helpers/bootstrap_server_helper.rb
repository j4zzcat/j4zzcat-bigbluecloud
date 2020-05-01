require 'sinatra/base'
require 'ipaddress'

HELPER_IP      = IPAddress::IPv4.new( %x[ hostname -I ].strip )
HELPER_PORT    = '7080'
HELPER_SUBNET  = IPAddress::IPv4.new( %x[ ip addr | grep $(hostname -I) | awk '{print $2}' ].strip ).network
HELPER_NETMASK = HELPER_SUBNET.netmask
HELPER_GATEWAY = %x[ ip route show default | awk '/#{HELPER_IP.to_s}/{print $3}' ].chomp
HELPER_DNS     = %x[ systemd-resolve --status | tail | awk -F ':' '/DNS Servers/{print $2}'].strip
HELPER_DOMAIN  = %x[ systemd-resolve --status | tail | awk -F ':' '/DNS Domain/{print $2}'].strip

HELPER_STATE_DIR = "."
HELPER_REGISTAR  = "#{HELPER_STATE_DIR}/#{File.basename( $0, File.extname( $0 ) )}.registar"

# OPENSHIFT_CLUSTER_NAME = %x[ ls -l /opt/openshift/install | awk '/#{HELPER_DOMAIN}/{print $9}' | awk -F '.' '{print $1}' ]
OPENSHIFT_CLUSTER_NAME = 'rover'

BAD_REQUEST = 400

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

    get '/netmask_of' do
      net_address = params[ 'net_address' ]
      IPAddress::IPv4.new( net_address ).netmask
    end

    get '/prepare/:openshift_node_type' do
      client_ip           = request.ip
      openshift_node_type = params[ 'openshift_node_type' ]

      probe = <<~EOT
        instance_id=$(cloud-init query instance_id)
        net_address=$(ip addr | grep -e 'inet ' | grep #{client_ip} | awk '{print $2}')
        net_netmask=$(curl -X GET \
                        --data "net_address=${net_address}" \
                        http://#{HELPER_IP}:#{HELPER_PORT}/netmask_of)
        net_ip=$(echo ${net_address} | awk -F '/' '{print $1}')
        net_gateway=$(ip route show default | awk '{print $3}')
        curl -X POST \
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
      net_ip              = params[ 'net_ip' ]
      net_netmask         = params[ 'net_netmask' ]
      net_gateway         = params[ 'net_gateway' ]
      openshift_node_type = params[ 'openshift_node_type' ]

      record = "#{instance_id} #{net_ip} #{net_netmask} #{net_gateway} #{openshift_node_type}"
      %x[ sed --in-place -e "d/^#{instance_id} .*/" #{HELPER_REGISTAR} ]
      %x[ echo "#{record}" >> #{HELPER_REGISTAR} ]
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

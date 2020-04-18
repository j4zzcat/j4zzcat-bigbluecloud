require 'sinatra/base'

PORT = '7080'

class PoormansDDNS
  def run
    WebApp.set :my_ip, %x[ ip address show dev ens3 | awk '/inet /{print $2}' ].chomp.split( '/' )[ 0 ]
    WebApp.set :my_port, PORT

    Rack::Server.start( {
      server: 'thin',
      Host:   '0.0.0.0',
      Port:   PORT,
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
      type = params[ 'type' ]
      return <<~EOT
        apt update
        apt install -y ipxe
        sed --in-place -e 's/GRUB_DEFAULT=0/GRUB_DEFAULT=ipxe/' /etc/default/grub
        sed --in-place -e 's/--class network {/--class network --id ipxe {/' /etc/grub.d/20_ipxe
        sed --in-place -e 's|linux16.*|linux16 $IPXEPATH dhcp \\\\&\\\\& chain http://#{settings.my_ip}:#{settings.my_port}/boot?type=#{type}|' /etc/grub.d/20_ipxe
        update-grub
        # reboot
      EOT
    end

    get '/boot/:type' do
      type = params[ 'type' ]
      return <<~EOT
        #!ipxe
        dhcp
        route
        kernel http://#{settings.my_ip}/images/rhcos/rhcos-4.3.8-x86_64-installer-kernel-x86_64 coreos.inst=yes coreos.inst.install_dev=sda coreos.inst.image_url=http://#{settings.my_ip}/images/rhcos/metal.x86_64.raw.gz coreos.inst.ignition_url=http://#{settings.my_ip}/config/#{type}_config.ign ip=dhcp
        initrd http://#{settings.my_ip}/images/rhcos/rhcos-4.3.8-x86_64-installer-initramfs.x86_64.img
        boot
      EOT
    end

  end
end

BootstrapServer.new.run

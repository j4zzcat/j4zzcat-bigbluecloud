require 'sinatra/base'

class BootstrapServer
  def run
    WebApp.set :my_ip, %x[ ip address show dev ens3 | awk '/inet /{print $2}' ].chomp.split( '/' )[ 0 ]
    WebApp.set :my_port, '8070'

    Rack::Server.start( {
      server: 'thin',
      Host:   '0.0.0.0',
      Port:   '8070',
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

    get '/bootstrap' do
      return <<~EOT
        instnace_id=$(cloud-init query instance_id)
        hostname=$(cloud-init query local_hostname)
        ip=$(hostname -I)
        curl http://#{settings.my_ip}:#{settings.my_port}/register?instance_id=${instnace_id}\?hostname=${hostname}\?ip=${ip}
        apt update
        apt install -y ipxe
        sed --in-place -e 's/GRUB_DEFAULT=0/GRUB_DEFAULT=ipxe/' /etc/default/grub
        sed --in-place -e 's/--class network {/--class network --id ipxe {/' /etc/grub.d/20_ipxe
        sed --in-place -e 's|linux16.*|linux16 $IPXEPATH dhcp \\&\\& chain http://#{settings.my_ip}:#{settings.my_port}/boot?instance_id=${instance_id}|' /etc/grub.d/20_ipxe
        update-grub
        # reboot
      EOT
    end

    get '/register' do
      instance_id = params[ 'instance_id' ]
      hostname    = params[ 'hostname' ]
    end

    get '/boot' do
      instance_id = params[ 'instance_id' ]
    end

  end
end

BootstrapServer.new.run

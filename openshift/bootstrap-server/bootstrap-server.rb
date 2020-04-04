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
      instance_id = params[ 'instance_id' ]
      hostname    = params[ 'hostname' ]

      if instance_id.nil?
        return <<~EOT
          instnace_id=$(cloud-init query instance_id)
          hostname=$(cloud-init query local_hostname)
          curl http://#{settings.my_ip}:#{settings.my_port}/instance_id=${instnace_id}\?hostname=${hostname}
          echo apt install ipxe
        EOT
      end

      "echo '#{instnace_id}'"

    end
  end
end

BootstrapServer.new.run

require 'sinatra/base'

class BootstrapServer
  def run
    WebApp.set :my_ip, %x[ hostname -I ].chomp
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
      puts params
      instance_id = params[ 'instance_id' ]
      hostname    = params[ 'hostname' ]

      return "bash -c $(curl http://#{settings.my_ip}:#{settings.my_port}/instance_id=$(cloud-init query instance_id))" if instance_id.nil?

      "echo '#{instnace_id}'"

    end
  end
end

BootstrapServer.new.run

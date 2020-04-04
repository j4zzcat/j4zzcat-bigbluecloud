require 'sinatra/base'

class BootstrapServer
  def run
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
    get '/bootstrap' do
      instance_id = param[ 'instance_id' ]
      hostname    = param[ 'hostname' ]

      "echo 'Hello World!'" if instance_id.nil?

      "echo 'Blah!'"

    end
  end
end

BootstrapServer.new.run

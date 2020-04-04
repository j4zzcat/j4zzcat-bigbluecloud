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
      puts params
      instance_id = params[ 'instance_id' ]
      hostname    = params[ 'hostname' ]

      return "echo 'Hello World!'" if instance_id.nil?

      "echo 'Blah!'"

    end
  end
end

BootstrapServer.new.run

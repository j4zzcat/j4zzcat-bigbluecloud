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
      "echo 'Hello World!'"
    end
  end
end

BootstrapServer.new.run

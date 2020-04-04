require 'sinatra/base'

class BootstrapServer
  def run
    logger.info "Listening on '0.0.0.0:8070..."
    Rack::Server.start( {
      server: 'thin',
      Host:   '0.0.0.0',
      Port:   Resources.p( :DEFAULT_SERVER_PORT ),
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

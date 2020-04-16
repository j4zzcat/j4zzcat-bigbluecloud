require 'sinatra/base'

PORT = '7080'

class NameServerHelper
  def run
    WebApp.set :my_domain, %x[ cat /etc/dnsmasq.conf | awk -F '=' '/^domain=/{print $2}' ].chomp

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

    post '/registar/:ip' do
      ip       = params[ 'ip' ]
      hostname = params[ 'hostname' ]

      return 400 if hostname.count( '.' ) > 0
      return 400 if hostname.count( ' ' ) > 0
      return 409 if %x[ cat /etc/hosts | grep --count -e "^#{ip}" ].chomp != '0'
      # TODO test if given ip is in our subnet

      %x[ echo "#{ip} #{hostname}.#{settings.my_domain}" >> /etc/hosts ]
      200
    end
  end
end

NameServerHelper.new.run

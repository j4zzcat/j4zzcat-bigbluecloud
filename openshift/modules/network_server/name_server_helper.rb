require 'sinatra/base'
require 'ipaddress'

PORT = '7080'

class NameServerHelper
  def run
    WebApp.set :my_ip,     IPAddress::IPv4.new( %x[ hostname -I ].strip )
    WebApp.set :my_subnet, IPAddress::IPv4.new( %x[ ip addr | grep $(hostname -I) | awk '{print $2}' ].strip ).network
    WebApp.set :my_domain, %x[ cat /etc/dnsmasq.conf | awk -F '=' '/^domain=/{print $2}' ].chomp
    WebApp.set :my_reserved_ips, [
      WebApp.settings.my_ip,
      WebApp.settings.my_subnet.first,
      IPAddress::IPv4.parse_u32( WebApp.settings.my_subnet.first.to_i + -1 ),
      IPAddress::IPv4.parse_u32( WebApp.settings.my_subnet.first.to_i + 1 ),
      IPAddress::IPv4.parse_u32( WebApp.settings.my_subnet.first.to_i + 2 ),
      WebApp.settings.my_subnet.last ]

    puts "Starting..."
    puts "my_ip: #{WebApp.settings.my_ip.to_s}"
    puts "my_subnet: #{WebApp.settings.my_subnet.to_s}"
    puts "my_domain: #{WebApp.settings.my_domain}"
    puts "my_reserved_ips: #{WebApp.settings.my_reserved_ips.map { |ip| ip.to_s } }"

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
      ip = nil
      begin
        ip = IPAddress::IPv4.new params[ 'ip' ]
      rescue
        return 400
      end

      # check for reserved ips
      return 400 if settings.my_reserved_ips.include?( ip )

      # check for duplicates
      return 409 if %x[ cat /etc/hosts | grep --count -e "^#{ip.to_s}" ].chomp != '0'

      # only allow ips in my own subnet
      return 400 if !settings.my_subnet.include? ip

      # validate hostname
      hostname = params[ 'hostname' ]
      return 400 if /^[a-zA-Z0-9][a-zA-Z0-9\-]*$/.match( hostname ) == nil
      return 400 if hostname.length > 32

      %x[ echo "#{ip.to_s} #{hostname}.#{settings.my_domain}" >> /etc/hosts ]
      200
    end
  end
end

NameServerHelper.new.run

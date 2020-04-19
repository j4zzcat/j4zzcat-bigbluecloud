require 'sinatra/base'
require 'ipaddress'

MY_IP     = IPAddress::IPv4.new( %x[ hostname -I ].strip )
MY_PORT   = '7080'
MY_SUBNET = IPAddress::IPv4.new( %x[ ip addr | grep $(hostname -I) | awk '{print $2}' ].strip ).network
MY_DOMAIN = %x[ cat /etc/dnsmasq.conf | awk -F '=' '/^domain=/{print $2}' ].chomp
MY_SUBNET_RESERVED_IPS = [
  MY_IP,
  IPAddress::IPv4.parse_u32( MY_SUBNET.first.to_i ),
  IPAddress::IPv4.parse_u32( MY_SUBNET.first.to_i + -1 ),
  IPAddress::IPv4.parse_u32( MY_SUBNET.first.to_i + 1 ),
  IPAddress::IPv4.parse_u32( MY_SUBNET.first.to_i + 2 ),
  IPAddress::IPv4.parse_u32( MY_SUBNET.last.to_i ) ]

class NameServerHelper
  def run
    puts "Starting..."
    puts "MY_IP: #{MY_IP.to_s}"
    puts "MY_PORT: #{MY_PORT}"
    puts "MY_SUBNET: #{MY_SUBNET.to_s}"
    puts "MY_DOMAIN: #{MY_DOMAIN}"
    puts "MY_SUBNET_RESERVED_IPS: #{MY_SUBNET_RESERVED_IPS.map { | ip | ip.to_s }}"

    Rack::Server.start( {
      server: 'thin',
      Host:   '0.0.0.0',
      Port:   MY_PORT,
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
      return 400 if MY_SUBNET_RESERVED_IPS.include?( ip )

      # check for duplicates
      return 409 if %x[ cat /etc/hosts | grep --count -e "^#{ip.to_s}" ].chomp != '0'

      # only allow ips in my own subnet
      return 400 if !MY_SUBNET.include? ip

      # validate hostname
      hostname = params[ 'hostname' ]
      return 400 if /^[a-zA-Z0-9][a-zA-Z0-9\-]*$/.match( hostname ) == nil
      return 400 if hostname.length > 32

      %x[ echo "#{ip.to_s} #{hostname}.#{MY_DOMAIN}" >> /etc/hosts ]
      200
    end
  end
end

NameServerHelper.new.run

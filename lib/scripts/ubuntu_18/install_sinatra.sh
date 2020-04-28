DEBIAN_FRONTEND=noninteractive apt-get install -qq -y \
  ruby2.5-dev gcc g++ make

mkdir -p /var/sinatra/www

gem install -q --no-document bundle sinatra thin ipaddress

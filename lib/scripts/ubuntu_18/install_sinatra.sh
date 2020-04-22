DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ruby2.5-dev gcc g++ make

mkdir -p /var/sinatra/www

gem install --no-document bundle sinatra thin ipaddress

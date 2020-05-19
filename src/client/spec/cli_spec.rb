require 'bigbluecloud'

RSpec.describe BigBlueCloud::Cli do
  cli = BigBlueCloud::Cli.new(
    'us-south',
    ENV[ 'IBMCLOUD_API_KEY' ],
    ENV[ 'IAAS_CLASSIC_USERNAME' ],
    ENV[ 'IAAS_CLASSIC_API_KEY' ] )

  it 'fails nicely' do
    begin
      cli.execute 'blah'
    rescue => e
      expect( e.exit_status ).to eq 2
      expect( e.std_out_err[ 0 .. 5 ] ).to eq 'FAILED'
    end
  end

  it 'logins to the cloud' do
    cli.login
  end

  it 'lists classic vms' do
    result = cli.execute 'sl vs list', json: true
    p result
  end
end

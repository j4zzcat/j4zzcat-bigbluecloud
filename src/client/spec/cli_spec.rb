require 'bigbluecloud'

RSpec.describe BigBlueCloud::Cli do
  cli = BigBlueCloud::Cli.new(
    'us-south',
    ENV[ 'IBMCLOUD_API_KEY' ],
    ENV[ 'IAAS_CLASSIC_USERNAME' ],
    ENV[ 'IAAS_CLASSIC_API_KEY' ] )

  it 'fails correctly' do
    begin
      cli.execute 'blah'
    rescue => e
      expect( e.exit_status ).to eq 2
      expect( e.std_out_err[ 0 .. 5 ] ).to eq 'FAILED'
    end
  end

  # it 'logins' do
  #   cli.login
  # end
end

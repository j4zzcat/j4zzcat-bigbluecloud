require 'json'
require 'open3'

module BigBlueCloud
  class Cli
    class Error < BigBlueCloud::StandardError
      attr_reader :exit_status, :std_out_err
      def initialize( exit_status, std_out_err )
        @exit_status = exit_status
        @std_out_err = std_out_err
      end
    end

    def initialize( region, ibmcloud_api_key,  iaas_classic_username, iaas_classic_api_key )
      @region                = region
      @ibmcloud_api_key      = ibmcloud_api_key
      @iaas_classic_username = iaas_classic_username
      @iaas_classic_api_key  = iaas_classic_api_key
    end

    def execute( cmd, env = nil, **kwargs )
      if kwargs[ :to_json ] == true
        plugin = cmd.split[ 0 ]
        if %w[ is ].include? plugin
          json_option = '--json'
        elsif %w[ tg ].include? plugin
          json_option = '--output json'
        end
      end

      env = {} if env.nil?
      env.merge!( { 'IBMCLOUD_COLOR' => 'false' } )

      cmd = "ibmcloud #{cmd} #{json_option}"

      result_exit_status, result_out_err = nil
      Open3.popen2e( env, cmd ) do | std_in, std_out_err, wait_thread |
        result_out_err      = std_out_err.read
        result_exit_status = wait_thread.value.exitstatus
      end

      raise Cli::Error.new result_exit_status, result_out_err if result_exit_status != 0

      if kwargs[ :to_json ] == true
        JSON.parse result_outerr
      elsif kwargs[ :to_raw ] == true
        result_outerr
      end
    end

    def login
      env = {
        'IBMCLOUD_API_KEY'      => @ibmcloud_api_key,
        'IAAS_CLASSIC_USERNAME' => @iaas_classic_username,
        'IAAS_CLASSIC_API_KEY'  => @iaas_classic_api_key }
      self.execute "login -r #{@region}", env
    end

  end # class
end # module

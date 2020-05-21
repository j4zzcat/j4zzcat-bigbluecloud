require 'json'
require 'open3'

module BigBlueCloud
  class Cli
    attr_reader :logged_in

    def initialize( region, ibmcloud_api_key, iaas_classic_username, iaas_classic_api_key )
      @region                = region
      @ibmcloud_api_key      = ibmcloud_api_key
      @iaas_classic_username = iaas_classic_username
      @iaas_classic_api_key  = iaas_classic_api_key

      @logged_in = false
    end

    def execute( cmd, env = nil, **kwargs )
      if kwargs[ :json ] == true
        plugin = cmd.split[ 0 ]
        if %w[ is ].include? plugin
          json_option = '--json'
        elsif %w[ tg sl ].include? plugin
          json_option = '--output=json'
        end
      end

      env = {} if env.nil?
      env.merge!( { 'IBMCLOUD_COLOR' => 'false' } )

      cmd = "ibmcloud #{cmd} #{json_option}"

      result_exit_status, result_out_err = nil
      Open3.popen2e( env, cmd ) do | std_in, std_out_err, wait_thread |
        result_out_err     = std_out_err.read
        result_exit_status = wait_thread.value.exitstatus
      end

      raise Cli::Error.new result_exit_status, result_out_err if result_exit_status != 0

      if kwargs[ :json ] == true
        JSON.parse result_out_err
      elsif kwargs[ :raw ] == true
        result_out_err
      end
    end

    def login( **kwargs )
      if @logged_in == false or kwargs[ :force ] == true
        env = {
          'IBMCLOUD_API_KEY'      => @ibmcloud_api_key,
          'IAAS_CLASSIC_USERNAME' => @iaas_classic_username,
          'IAAS_CLASSIC_API_KEY'  => @iaas_classic_api_key }

        self.execute "login -r #{@region}", env
        @logged_in = true
      end
    end

    class Error < BigBlueCloud::StandardError
      attr_reader :exit_status, :std_out_err
      def initialize( exit_status, std_out_err )
        @exit_status = exit_status
        @std_out_err = std_out_err
      end
    end

  end # class
end # module

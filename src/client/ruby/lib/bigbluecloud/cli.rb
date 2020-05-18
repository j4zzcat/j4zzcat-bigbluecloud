require 'json'

module BigBlueCloud
  class Cli
    class Error < BigBlueCloud::StandardError
      def initialize( exit_status, stdouterr )
        @exit_status = exit_status
        @stdouterr   = stdouterr
      end
    end

    def initialize( region )
      @region = region
    end

    def execute( cmd, **kwargs )
      if kwargs[ :to_json ] == true
        plugin = cmd.split[ 0 ]
        if %w[ is ].include? plugin
          json_option = '--json'
        elsif %w[ tg ].include? plugin
          json_option = '--output json'
        end
      end

      cmd = "ibmcloud #{cmd} #{json_option}"

      result_exit_status, result_outerr = nil
      Open3.popen2e( { 'IBMCLOUD_COLOR' => 'false' }, cmd ) do | stdin, stdout, stdouterr, wait_thread |
        result_outerr      = stdout.read
        result_exit_status = wait_thread.value.exit_status
      end

      raise Cli::Error.new result_exit_status, result_outerr if result_exit_status != 0

      if kwargs[ :to_json ] == true
        JSON.parse result_outerr
      elsif kwargs[ :to_raw ] == true
        result_outerr
      end
    end

    def login
      puts "Logging in to IBM Cloud..."
      self.execute "login -r #{@region}"
    end

  end # class
end # module

module HotTub
  module KnownClients
    KNOWN_CLIENTS = {
      "Excon::Connection" => {
        :close => lambda { |clnt| clnt.reset }
      },
      'EventMachine::HttpConnection' => {
        :close => lambda { |clnt|
          if clnt.conn
            clnt.conn.close_connection
            clnt.instance_variable_set(:@deferred, true)
          end
        },
        :clean => lambda { |clnt|
          if clnt.conn && clnt.conn.error?
            HotTub.logger.info "Sanitizing connection : #{EventMachine::report_connection_error_status(clnt.conn.instance_variable_get(:@signature))}"
            clnt.conn.close_connection
            clnt.instance_variable_set(:@deferred, true)
          end
          clnt
        }
      }
    }
    attr_accessor :options
    # Attempts to clean the provided client, checking the options first for a clean block
    # then checking the known clients
    def clean_client(clnt)
      return @options[:clean].call(clnt) if @options && @options[:clean] && @options[:clean].is_a?(Proc)
      if settings = KNOWN_CLIENTS[clnt.class.name]
        settings[:clean].call(clnt) if settings[:clean].is_a?(Proc)
      end
    end

    # Attempts to close the provided client, checking the options first for a close block
    # then checking the known clients
    def close_client(clnt)
      return @options[:close].call(clnt) if @options && @options[:close] && @options[:close].is_a?(Proc)
      if settings = KNOWN_CLIENTS[clnt.class.name]
        begin
          settings[:close].call(clnt) if settings[:close].is_a?(Proc)
        rescue => e
          HotTub.logger.error "There was an error close one of your #{self.class.name} connections: #{e}"
        end
      end
    end
  end
end

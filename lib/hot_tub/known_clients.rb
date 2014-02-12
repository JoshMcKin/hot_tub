module HotTub
  module KnownClients
    KNOWN_CLIENTS = {
      "Excon::Connection" => {
        :close => lambda { |clnt| clnt.reset }
      },
      "Net::HTTP" => {
        :close => lambda { |clnt|
          begin
            clnt.finish
          rescue IOError
            nil
          end
        }
      }
    }
    attr_accessor :options
    # Attempts to clean the provided client, checking the options first for a clean block
    # then checking the known clients
    def clean_client(clnt)
      begin
        return @clean_client.call(clnt) if @clean_client && @clean_client.is_a?(Proc)
        if settings = KNOWN_CLIENTS[clnt.class.name]
          settings[:clean].call(clnt) if settings[:clean].is_a?(Proc)
        end
      rescue => e
        HotTub.logger.error "There was an error cleaning one of your HotTub::Pool clients: #{e}"
      end
    end

    # Attempts to close the provided client, checking the options first for a close block
    # then checking the known clients
    def close_client(clnt)
      return @close_client.call(clnt) if @close_client && @close_client.is_a?(Proc)
      if settings = KNOWN_CLIENTS[clnt.class.name]
        begin
          settings[:close].call(clnt) if settings[:close].is_a?(Proc)
        rescue => e
          HotTub.logger.error "There was an error closing one of your #{self.class.name} connections: #{e}"
        end
      end
    end

    # Attempts to determine if a client should be reaped, block should return a boolean
    def reap_client?(clnt)
      return @reap_client.call(clnt) if @reap_client && @reap_client.is_a?(Proc)
      if settings = KNOWN_CLIENTS[clnt.class.name]
        begin
          settings[:reap].call(clnt) if settings[:reap].is_a?(Proc)
        rescue => e
          HotTub.logger.error "There was an error closing one of your #{self.class.name} connections: #{e}"
        end
      end
      return false
    end
  end
end

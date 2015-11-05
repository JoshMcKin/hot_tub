module HotTub
  module KnownClients
    KNOWN_CLIENTS = {
      "Excon::Connection" => {
        :close => :reset
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

    # Attempts to clean the provided client, checking the options first for a clean block
    # then checking the known clients
    def clean_client(clnt)
      if @clean_client
        begin
          perform_action(clnt,@clean_client)
        rescue => e
          HotTub.logger.error "[HotTub] There was an error cleaning one of your #{self.class.name} clients: #{e}" if HotTub.logger
        end
      end
      clnt
    end

    # Attempts to close the provided client, checking the options first for a close block
    # then checking the known clients
    def close_client(clnt)
      @close_action = (@close_client || known_client_action(clnt,:close) || false) if @close_action.nil?
      if @close_action
        begin
          perform_action(clnt,@close_action)
        rescue => e
          HotTub.logger.error "[HotTub] There was an error closing one of your #{self.class.name} clients: #{e}" if HotTub.logger
        end
      end
      nil
    end

    # Attempts to determine if a client should be reaped, block should return a boolean
    def reap_client?(clnt)
      rc = false
      if @reap_client
        begin
          rc = perform_action(clnt,@reap_client)
        rescue => e
          HotTub.logger.error "[HotTub] There was an error reaping one of your #{self.class.name} clients: #{e}" if HotTub.logger
        end
      end
      rc
    end

    private

    def known_client_action(clnt,key)
      (KNOWN_CLIENTS[clnt.class.name] && KNOWN_CLIENTS[clnt.class.name][key])
    end

    def perform_action(clnt,action)
      if action.is_a?(Proc)
        yield_action(clnt,&action)
      else
        clnt.__send__(action)
      end
    end

    # This is ever so slightly faster in MRI,
    #  more so on Rubinius and Jruby
    def yield_action(clnt)
      yield clnt
    end
  end
end

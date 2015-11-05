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
          if @clean_client.is_a?(Proc)
            preform_client_block(clnt,&@clean_client)
          else
            preform_client_method(clnt,@clean_client)
          end
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
          if @close_action.is_a?(Proc)
            preform_client_block(clnt,&@close_action)
          else
            preform_client_method(clnt,@close_action)
          end
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
          if @reap_client.is_a?(Proc)
            rc = preform_client_block(clnt,&@reap_client)
          else
            rc = preform_client_method(clnt,@reap_client)
          end
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

    def preform_client_block(clnt,action=nil)
      yield clnt
    end

    def preform_client_method(clnt,action=nil)
      clnt.send(action)
    end
  end
end

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
    # Attempts to clean the provided client, checking the options first for a clean block
    # then checking the known clients
    def clean_client(clnt)
      begin
        action = (@clean_client || known_client_action(clnt,:clean))
        preform_client_action(clnt,action) if action
      rescue => e
        HotTub.logger.error "There was an error cleaning one of your #{self.class.name} clients: #{e}"
      end
    end

    # Attempts to close the provided client, checking the options first for a close block
    # then checking the known clients
    def close_client(clnt)
      begin
        action = (@close_client || known_client_action(clnt,:close))
        preform_client_action(clnt,action) if action
      rescue => e
        HotTub.logger.error "There was an error closing one of your #{self.class.name} clients: #{e}"
      end
    end

    # Attempts to determine if a client should be reaped, block should return a boolean
    def reap_client?(clnt)
      begin
        action = (@reap_client || known_client_action(clnt,:reap))
        return preform_client_action(clnt,action) if action
      rescue => e
        HotTub.logger.error "There was an error reaping one of your #{self.class.name} clients: #{e}"
      end
      return false
    end

    private

    def known_client_action(clnt,key)
      (KNOWN_CLIENTS[clnt.class.name] && KNOWN_CLIENTS[clnt.class.name][key])
    end

    def preform_client_action(clnt,action)
      if action.is_a?(Proc)
        return action.call(clnt)
      elsif action.is_a?(Symbol)
        return clnt.send(action)
      end
      false
    end
  end
end

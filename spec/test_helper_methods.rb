module TestHelperMethods
  def keep_alive_test(client,&get_status_blk)
    responses = []
    start = Time.now
    
    50.times.each do
      c = client.dup # want a new client everytime
      responses.push get_status_blk.call(c)
    end
    
    normal = Time.now - start
    
    # we want a whole new pool to make sure we don't cheat
    connection_pool = HotTub::Session.new(
      :client => client)
    
    start = Time.now
    50.times.each do
      #responses.push get_status_blk.call(connection_pool.get)    
      connection_pool.run do |c|
        responses.push get_status_blk.call(c)
      end
      
    end
    
    keep_alive = Time.now - start
    
   
    puts "#{client.class.name} keep-alive: #{keep_alive}; normal: #{normal};"
    #puts responses.join(", ")
    (keep_alive < normal).should be_true
  end

end

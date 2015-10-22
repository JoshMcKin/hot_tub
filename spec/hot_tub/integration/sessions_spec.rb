require 'spec_helper'

describe HotTub, 'with sessions' do

  let(:url) { HotTub::Server.url }
  let(:url2) { HotTub::Server2.url }
  let(:sessions) do
    HotTub.new(:sessions => true) { |url|
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = false
      http.start
      http
    }
  end

  it "should work" do
    threads = []
    10.times.each do
      threads << Thread.new do
        sessions.run(url)  { |clnt| Thread.current[:result] = clnt.get(URI.parse(url).path).code }
        sessions.run(url2) { |clnt| Thread.current[:result] = clnt.get(URI.parse(url).path).code }
      end
    end
    threads.each do |t|
      t.join
    end
    results = threads.collect{ |t| t[:result]}
    expect(results.length).to eql(10) 
    expect(results.uniq).to eql([results.first]) 
    expect(sessions.instance_variable_get(:@sessions).keys.length).to eql(2) 
  end
end

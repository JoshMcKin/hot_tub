require 'spec_helper'

describe HotTub, 'with sessions' do

  let(:url) { HotTub::Server.url }
  let(:url2) { HotTub::Server2.url }


  let(:threads) { [] }

  let(:sessions) { HotTub::Sessions.new(:name => "intText") }

  before(:each) do
    sessions.add(url) {
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = false
      http.start
      http
    }

    sessions.add(url2) {
      Excon.new(url2)
    }


    5.times.each do
      threads << Thread.new do
        sessions.run(url) { |clnt| Thread.current[:result1] = clnt.get(URI.parse(url).path).code }
        sessions.run(url2) { |clnt| Thread.current[:result2] = clnt.get(:path => URI.parse(url2).path).status }
      end
    end
    threads.each do |t|
      t.join
    end
  end

  it "should create sessions" do
    expect(sessions.instance_variable_get(:@_sessions).keys.length).to eql(2)
  end

  it "should do work" do
    results = threads.collect{ |t| t[:result1]}
    expect(results.length).to eql(5)
    expect(results.uniq).to eql([results.first])
    results = threads.collect{ |t| t[:result2]}
    expect(results.length).to eql(5)
    expect(results.uniq).to eql([results.first])
  end

end

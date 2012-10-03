require 'test_helper_no_rails'
require 'elastic_search/connection'
require 'elastic_search/request'

describe ElasticSearch::Connection do

  describe "put" do
    # Sanitized version
#    it "processes the request" do
#      conn = ElasticSearch::Connection.new
#      request = ElasticSearch::Request.new "/path", {:run => "apos -> ' fslash -> /"}
#
#      ElasticSearch::Connection.expects(:put).with(
#        "/path", :body => MultiJson.encode({ "run" => "apos -> \\' fslash -> \\/"}))
#
#      conn.put request
#    end
    it "processes the request" do
      conn = ElasticSearch::Connection.new
      request = ElasticSearch::Request.new "/path", {:run => "test"}

      ElasticSearch::Connection.expects(:put).with(
        "/path", :body => MultiJson.encode({ "run" => "test"}))

      conn.put request
    end
  end

  describe "delete" do
    it "processes the request" do
      conn = ElasticSearch::Connection.new
      request = ElasticSearch::Request.new "/path", {:run => "this"}

      ElasticSearch::Connection.expects(:delete).with("/path")

      conn.delete request
    end
  end
end

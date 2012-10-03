require 'test_helper_no_rails'
require 'elastic_search/request'

describe ElasticSearch::Request do

  before do
    @request = ElasticSearch::Request.new "path", {:body => "this"}
  end

  it "takes a path and a body on creation" do
    @request.path.must_equal "path"
    @request.body.must_equal :body => "this"
  end

  it "can build a hash of all information needed for an object" do
    got = @request.to_hash
    got[:path].must_equal "path"
    got[:body].must_equal :body => "this"
  end

  describe "from_hash" do
    it "can build itself back from a hash" do
      got = ElasticSearch::Request.from_hash({:path => "something", :body => {:omg => "HAI!"}})
      got.path.must_equal "something"
      got.body.must_equal :omg => "HAI!"
    end

    it "handles symbol or string keys" do
      got = ElasticSearch::Request.from_hash({"path" => "something", "body" => {"omg" => "HAI!"}})
      got.path.must_equal "something"
      got.body.must_equal "omg" => "HAI!"
    end
  end

end

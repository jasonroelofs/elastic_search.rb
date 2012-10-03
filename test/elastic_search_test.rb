require 'test_helper_no_rails'
require 'elastic_search'
require 'elastic_search/query'
require 'elastic_search/results'
require 'elastic_search/model'

describe ElasticSearch do

  class NotMapped < Struct.new(:id, :name, :size)
  end

  class TestObject < Struct.new(:id, :name, :size)
    include ElasticSearch::Model

    elastic_search "testing" do
      field :name
      field :size

      only_if lambda {|obj| obj.name != "unapproved" }
    end
  end

  before do
    ElasticSearch.reset!
  end

  describe "configure" do
    it "sets host and port on connection" do
      ElasticSearch::Connection.expects(:base_uri).with("host:port")

      ElasticSearch.configure do |config|
        config.host = "host"
        config.port = "port"
        config.debug = false
      end
    end
  end

  describe "type conversions" do
    it "allows setting of type conversion blocks for results" do
      this = nil
      block = proc {|id| this = id }

      ElasticSearch.define_type_convert "type_key", &block

      convert_block = ElasticSearch.conversions["type_key"]
      convert_block.call(14)
      this.must_equal 14
    end
  end

  describe "index" do
    it "can take an ElasticSearch::Model for mapping" do
      tester = TestObject.new(1, "name", 4)

      ElasticSearch::Connection.any_instance.expects(:put).returns("results")

      ElasticSearch.index(tester).must_equal "results"
    end

    it "ignores if the request's body comes back as nil" do
      tester = TestObject.new(1, "unapproved", 4)

      ElasticSearch::Connection.any_instance.expects(:put).never

      ElasticSearch.index(tester).must_be_nil
    end

    it "raises if no mapping is found for the object" do
      tester = NotMapped.new(1, "name", 4)
      lambda {
        ElasticSearch.index(tester)
      }.must_raise ElasticSearch::UnknownMappingError
    end

  end

  describe "delete" do
    it "asks ES to remove the given object from its index" do
      tester = TestObject.new(1, "name", 4)

      ElasticSearch::Connection.any_instance.expects(:delete).returns("results")

      ElasticSearch.delete(tester).must_equal "results"
    end

    it "raises if no mapping is found for the object" do
      tester = NotMapped.new(1, "name", 4)
      lambda {
        ElasticSearch.delete(tester)
      }.must_raise ElasticSearch::UnknownMappingError
    end
  end

  describe "search" do
    it "takes a query, sends out a search request and returns a Results" do
      q = ElasticSearch::Query.new

      body = MultiJson.encode({:hits => {:hits => ["that"]}})
      returned = MiniTest::Mock.new
      returned.expect(:success?, true, [])
      returned.expect(:body, body, [])

      ElasticSearch::Connection.expects(:post).with(
        "/path/_search", {:body => MultiJson.encode(q.body)}).returns(returned)

      results = ElasticSearch.search("/path", q)
      results.must_be_kind_of ElasticSearch::Results

      results.query.must_equal q
      results.body.must_equal  "hits" => {"hits" => ["that"]}
    end

    it "throws an error if the request doesn't come back successfully" do
      q = ElasticSearch::Query.new

      body = MultiJson.encode({"error" => "Something Happened", "status" => 404})
      returned = MiniTest::Mock.new
      returned.expect(:success?, false, [])
      returned.expect(:body, body, [])

      ElasticSearch::Connection.expects(:post).with(
        "/path/_search", {:body => MultiJson.encode(q.body)}).returns(returned)

      lambda {
        results = ElasticSearch.search("/path", q)
      }.must_raise ElasticSearch::QueryError
    end
  end

  describe "defer" do
    it "raises if there's no mapping defined for the object given" do
      tester = NotMapped.new(1, "name", 4)
      ElasticSearch.job_queue = stub_everything

      lambda {
        ElasticSearch.defer(:index, tester)
      }.must_raise ElasticSearch::UnknownMappingError
    end

    it "raises if no job queue has been set yet" do
      lambda {
        ElasticSearch.defer(:index, "some object")
      }.must_raise ElasticSearch::NoJobQueueError
    end

    it "passes off handling of the object to the configured background handler" do
      tester = TestObject.new(1, "name", 4)
      background = mock()

      ElasticSearch.job_queue = background

      background.expects(:enqueue).with do |method, mapping_hash|
        method.must_equal :index
        mapping_hash.must_be_kind_of Hash
        mapping_hash[:path].wont_be_nil
        mapping_hash[:body].wont_be_nil
        true
      end

      ElasticSearch.defer(:index, tester)
    end
  end

  describe "execute" do

    it "sends a raw request to ElasticSearch" do
      ElasticSearch::Connection.expects(:send).with(
        :post, "/index/type/4", :body => {:name => "this"})

      ElasticSearch.execute(:post, "/index/type/4", {:name => "this"})
    end

  end

end

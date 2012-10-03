require 'test_helper_no_rails'
require 'elastic_search/results'
require 'elastic_search/query'
require 'elastic_search/model'

describe ElasticSearch::Results do

  before do
    @query = ElasticSearch::Query.new
    @query.query = "query"
    @query.current_page = 2
    @query.page_size = 4

    obj = {"name" => "My Object"}

    @response_body = {
      "hits" => {
        "hits" => [
          {"_score" => 1, "_id" => 2, "_type" => "this", "_source" => obj},
          {"_score" => 0.9, "_id" => 3, "_type" => "that", "_source" => obj},
          {"_score" => 0.8, "_id" => 4, "_type" => "those", "_source" => obj},
          {"_score" => 0.7, "_id" => 5, "_type" => "those", "_source" => obj}
        ],
        "total" => 12,
        "max_score" => 0.88776
      }
    }

    @results = ElasticSearch::Results.new @query, @response_body
  end

  it "is Enumerable" do
    @results.respond_to?(:map).must_equal true
    @results.respond_to?(:select).must_equal true
    @results.respond_to?(:each).must_equal true
  end

  it "takes the query and the response body hash" do
    @results.query.must_equal @query
    @results.body.must_equal @response_body
  end

  describe "results set" do
    it "allows iterating over all results" do
      got = []
      @results.each do |result|
        got << result
      end

      got.length.must_equal 4
    end

    it "allows access to a direct member" do
      @results[1].must_equal @response_body["hits"]["hits"][1]
      @results[2].must_equal @response_body["hits"]["hits"][2]
      @results[4].must_be_nil
    end

    it "knows if the result set is empty" do
      @results.empty?.must_equal false
    end
  end

  describe "result set type conversions" do
    class This
      attr_reader :id
      def initialize(id)
        @id = id
      end
    end

    class That
      attr_reader :id
      def initialize(id)
        @id = id
      end
    end

    class ThisAsModel < This
      include ElasticSearch::Model
    end

    it "converts results according to conversions definitions" do
      conversions = {
        "this" =>  proc { |id| This.new id },
        "that" =>  proc { |id| That.new id }
      }

      results = ElasticSearch::Results.new @query, @response_body, conversions

      results[0].must_be_kind_of This
      results[0].id.must_equal 2

      results[1].must_be_kind_of That
      results[1].id.must_equal 3

      results[2].must_be_kind_of Hash
      results[3].must_be_kind_of Hash
    end

    it "removes search results from the list that fail to convert" do
      conversions = {
        "this" =>  proc { |id| This.new id },
        "that" =>  proc { |id| raise "OMG NO!" }
      }

      results = ElasticSearch::Results.new @query, @response_body, conversions

      results[0].must_be_kind_of This
      results[0].id.must_equal 2

      results[1].must_be_kind_of Hash
      results[2].must_be_kind_of Hash
    end

    it "populates es_document if the object is an ElasticSearch::Model" do
      conversions = {
        "this" =>  proc { |id| ThisAsModel.new id },
        "that" =>  proc { |id| That.new id }
      }

      results = ElasticSearch::Results.new @query, @response_body, conversions

      results[0].must_be_kind_of This
      results[0].id.must_equal 2
      results[0].es_document.must_equal "name" => "My Object"
    end

  end

  describe "total_entries" do
    it "knows the total number of hits" do
      @results.total_entries.must_equal 12
    end

    it "handles counting bad requests" do
      results = ElasticSearch::Results.new @query, {}
      results.total_entries.must_equal 0
    end
  end

  describe "pagination" do
    it "knows the current page" do
      @results.current_page.must_equal 2
    end

    it "can figure out the previous page" do
      @results.previous_page.must_equal 1
    end

    it "knows that there is no previous page from page 1" do
      @query.current_page = 1
      @results.previous_page.must_be_nil
    end

    it "can figure out the next page" do
      @results.next_page.must_equal 3
    end

    it "knows the end of the pagination sequence" do
      @query.current_page = 3
      @results.next_page.must_be_nil
    end

    it "can figure out how many pages in the full results set" do
      @results.total_pages.must_equal 3
    end

    it "properly rounds up to the next integer" do
      @query.page_size = 10
      @results.total_pages.must_equal 2
    end

    it "knows the size of a page" do
      @results.per_page.must_equal 4
    end
  end
end

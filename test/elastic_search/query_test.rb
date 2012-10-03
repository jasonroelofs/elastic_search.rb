require 'test_helper_no_rails'
require 'elastic_search/query'

describe ElasticSearch::Query do

  before do
    @query = ElasticSearch::Query.new
  end

  it "builds a search body" do
    @query.body.must_be_kind_of Hash
  end

  describe "query" do
    it "includes the query string in the body" do
      @query.query = "query_string"
      @query.body[:query].must_equal :query_string => {:query => "query_string" }
    end

    it "ignores query if no or blank query given" do
      @query.body[:query].must_be_nil

      @query.query = ""
      @query.body[:query].must_be_nil
    end
  end

  describe "sorting" do
    it "always sorts by _score descending" do
      @query.body[:sort].must_equal [
        "_score"
      ]
    end

    it "knows how to sort the results" do
      @query.add_sort_by "random_field", "asc"

      @query.body[:sort].length.must_equal 2
      @query.body[:sort][0].must_equal "random_field" => "asc"
    end
  end

  describe "pagination" do
    it "can be told where in the result set to start giving results" do
      @query.current_page = 10
      @query.body[:from].must_equal 90
      @query.current_page.must_equal 10
    end

    it "can be told how big a page is" do
      @query.page_size = 14
      @query.body[:size].must_equal 14
      @query.page_size.must_equal 14
    end
  end

  describe "filters" do
    it "will add requested filters to the query" do
      @query.filter_on "organization_id" => 14
      @query.body[:filter][:and][0][:term].must_equal "organization_id" => 14
    end

    it "allows multiple filters" do
      @query.filter_on "organization_id" => 14
      @query.filter_on "keyword" => "some value"

      @query.body[:filter][:and][0][:term].must_equal "organization_id" => 14
      @query.body[:filter][:and][1][:term].must_equal "keyword" => "some value"
    end
  end

end

require 'test_helper_no_rails'
require 'elastic_search/model'

describe ElasticSearch::Model do

  class BasicModel
    include ElasticSearch::Model

    attr_accessor :id, :name

    elastic_search "basic_index" do
      field :name
    end
  end

  it "wraps the block in a Mapping and exposes it" do
    BasicModel.es_mapping.wont_be_nil
    BasicModel.es_mapping.must_be_kind_of ElasticSearch::Mapping
  end

  it "adds ability to create an ElasticSearch::Request from the object" do
    test = BasicModel.new
    test.id = 14
    test.name = "This is cool"

    request = test.es_build_request
    request.wont_be_nil
    request.path.must_equal "/basic_index/BasicModel/14"
    request.body.must_equal :name => "This is cool"
  end

  it "exposes an es_document hook for search results" do
    BasicModel.new.respond_to?(:es_document).must_equal true
    BasicModel.new.es_document.must_be_nil
  end

end

require 'test_helper_no_rails'
require 'elastic_search/model'
require 'elastic_search/mapping'

describe ElasticSearch::Mapping do

  class TestObj
    attr_accessor :id, :name, :bool_field, :description

    def calculated_field_1
      1
    end

    def calculated_field_2(this)
      this * this
    end
  end

  before do
    @mapping = ElasticSearch::Mapping.new "index_name" do
      field :name
      field :description
      field :bool_field, :boolean

      field :calculated_field_1

      field :field_2 do |obj|
        obj.calculated_field_2(14)
      end

      field :lambda_test, lambda {|obj| obj.id * 20 }

      field :type_block, :boolean do |obj|
        nil
      end
    end

  end

  it "takes a path and a block" do
    @mapping.wont_be_nil
  end

  describe "mapping types to create a request" do
    before do
      @object = TestObj.new
      @object.id = 14
      @object.name = "This cool"
      @object.description = "Another string?"
      @object.bool_field = nil

      @request = @mapping.build_request @object
    end

    it "builds the appropriate path with type and id" do
      @request.path.must_equal "/index_name/TestObj/14"
    end

    it "maps un-typed fields straight through" do
      @request.body[:name].must_equal "This cool"
      @request.body[:description].must_equal "Another string?"
    end

    it "processes values according to given types" do
      @request.body[:bool_field].must_equal false
    end

    it "calls methods on the object" do
      @request.body[:calculated_field_1].must_equal 1
    end

    it "calls defined blocks and lambdas in the mapping" do
      @request.body[:field_2].must_equal 14 * 14
      @request.body[:lambda_test].must_equal 280
      @request.body[:type_block].must_equal false
    end
  end

  describe "changing the type string" do
    class BadlyTyped < Struct.new(:id, :name, :approved)
    end

    it "allows specifying a different type string" do
      mapping = ElasticSearch::Mapping.new "testing" do
        type "better_type"

        field :name
      end

      model = ApprovedModel.new(4, false)
      r = mapping.build_request(model)
      r.path.must_equal "/testing/better_type/4"
    end
  end

  describe "mapping hooks" do

    class ApprovedModel < Struct.new(:id, :name, :approved)
    end

    it "can check if the object should be mapped or not" do
      mapping = ElasticSearch::Mapping.new "testing" do
        field :name
        only_if :approved
      end

      model = ApprovedModel.new(4, false)
      r = mapping.build_request(model)
      r.body.must_be_nil
    end

    it "can call a block to know if the object can be mapped" do
      mapping = ElasticSearch::Mapping.new "testing" do
        field :name
        only_if lambda {|obj| obj.id % 10 == 0 }
      end

      model = ApprovedModel.new(4, true)
      r = mapping.build_request(model)
      r.body.must_be_nil

      model = ApprovedModel.new(100, true)
      r = mapping.build_request(model)
      r.body.wont_be_nil
    end

  end

end

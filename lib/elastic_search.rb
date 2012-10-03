require 'multi_json'
require 'yajl'

require 'elastic_search/connection'
require 'elastic_search/mapping'
require 'elastic_search/model'
require 'elastic_search/query'
require 'elastic_search/request'
require 'elastic_search/results'

module ElasticSearch
  class UnknownMappingError < RuntimeError
    def initialize(klass)
      super("Cannot map object of type #{klass} to ElasticSearch. See ElasticSearch::Model for details on how to define a mapping")
    end
  end

  class NoJobQueueError < RuntimeError
    def initialize
      super("No job_queue defined. Set one with ElasticSearch.job_queue= or in the ElasticSearch.configure block")
    end
  end

  class QueryError < RuntimeError
    attr_reader :status, :message

    def initialize(message, status)
      @status = status
      @message = message

      super("Expected a 200 but got a #{status}: #{message}")
    end
  end

  class << self
    ##
    # Host elasticsearch is running on
    ##
    attr_accessor :host

    ##
    # Port elasticsearch is running on
    ##
    attr_accessor :port

    ##
    # Hash of defined type conversions
    ##
    attr_reader :conversions

    ##
    # Define what background processing queue to use
    # for defer-d operations. A job queue object simply needs to
    # implement the #enqueue method that takes a Mapping and the
    # object being mapped.
    ##
    attr_accessor :job_queue

    attr_accessor :debug

    def configure
      yield self

      ElasticSearch::Connection.base_uri "#{@host}:#{@port}"
      ElasticSearch::Connection.debug_output if @debug
    end

    ##
    # Specify a block, taking one parameter +id+ that will be used to replace
    # search results with an object from whatever persistence store your app
    # uses. For example, to load a class from ActiveRecord models, you'd define
    # something like this:
    #
    #   ElasticSearch.define_type_convert "student" do |id|
    #     Student.find(id)
    #   end
    #
    ##
    def define_type_convert(type, &block)
      @conversions ||= {}
      @conversions[type] = block
    end

    ##
    # Add the object to it's defined index as mapped through #define_mapping
    # Raises an error if a mapping is not defined for the object's type
    #
    # If given a random object, will check against all known mappings and
    # build a request or error out. Can also be given a Request directly.
    ##
    def index(obj_or_request)
      request = get_request(obj_or_request)
      Connection.new.put request if request.body
    end

    ##
    # Remove an object from the ES index it's defined to be under.
    # Raises an error if a mapping is not defined for the object's type
    #
    # If given a random object, will check against all known mappings and
    # build a request or error out. Can be also given a Request directly.
    ##
    def delete(obj_or_request)
      Connection.new.delete get_request(obj_or_request)
    end

    ##
    # Run a search. Returns an ElasticSearch::Results object with the results.
    #
    # +index_path+ is the /[index]/[type] path you want to search on
    # +query+ must be an ElasticSearch::Query object
    ##
    def search(index_path, query)
      results = Connection.post(
        [index_path, "_search"].join("/"),
        :body => MultiJson.encode(query.body)
      )
      results_body = MultiJson.decode(results.body)
      if results.success?
        ElasticSearch::Results.new query, results_body, @conversions
      else
        raise QueryError.new(results_body["error"], results_body["status"])
      end
    end

    ##
    # Using a background process of some sort, defined in [to define here],
    # process the object as needed then send the resulting information down
    # to the background process to execute the method requested.
    #
    # +method+ must be a method on ElasticSearch
    # +object+ must have a mapping through #define_mapping
    ##
    def defer(method, object)
      raise NoJobQueueError.new unless @job_queue
      @job_queue.enqueue method, get_request(object).to_hash
    end

    ##
    # Run a raw HTTP request directly against ElasticSearch
    ##
    def execute(http_method, path, request_body = {})
      Connection.send(http_method, path, :body => request_body)
    end

    ##
    # Clear out all defined mappings and type conversions
    # TODO Figure out a more testable setup than class variables?
    ##
    def reset!
      @conversions = {}
      @job_queue = nil
    end

    private

    def get_request(obj_or_request)
      case obj_or_request
      when ElasticSearch::Request
        obj_or_request
      when ElasticSearch::Model
        obj_or_request.es_build_request
      else
        raise UnknownMappingError.new(obj_or_request.class)
      end
    end
  end
end

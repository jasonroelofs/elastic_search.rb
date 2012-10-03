require 'elastic_search/mapping'

module ElasticSearch
  module Model

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods

      ##
      # Store the defined block wrapped in a Mapping
      ##
      attr_reader :es_mapping

      ##
      # Build a block that defines how this object maps
      # to an ElasticSearch document
      ##
      def elastic_search(index, &block)
        @es_mapping = ElasticSearch::Mapping.new index, &block
      end

    end

    ##
    # This attribute will contain a Hash of the document
    # as it's stored in ElasticSearch.
    ##
    attr_accessor :es_document

    ##
    # From the mapping defined on the class, build an ElasticSearch::Request
    # object to be sent to ElasticSearch
    ##
    def es_build_request
      self.class.es_mapping.build_request(self)
    end

  end
end

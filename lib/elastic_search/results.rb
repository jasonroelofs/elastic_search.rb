require 'enumerator'
#require 'elastic_search/model'

module ElasticSearch

  ##
  # This object wraps up the results of an ElasticSearch query
  # and offers up a will_paginate-compatible results list
  ##
  class Results
    include Enumerable

    attr_reader :query, :body

    ##
    # Build a new results set from results given
    ##
    def initialize(query, body, conversions = {})
      @query = query
      @body = body
      @processed = false
      @conversions = conversions
    end

    ##
    # Iterate over the results set
    ##
    def each(&block)
      process_results unless @processed
      @results.each(&block)
    end

    ##
    # Access a specific result
    ##
    def [](idx)
      process_results unless @processed
      @results[idx]
    end

    def total_entries
      @body["hits"]["total"] rescue 0
    end

    def current_page
      @query.current_page
    end

    def next_page
      current_page < total_pages ? current_page + 1 : nil
    end

    def previous_page
      current_page > 1 ? current_page - 1 : nil
    end

    def total_pages
      (self.total_entries.to_f / self.per_page.to_f).ceil
    end

    def per_page
      @query.page_size
    end

    def empty?
      total_entries == 0
    end

    protected

    def process_results
      @results =
        @body["hits"]["hits"].map do |result|
          if convert = @conversions[result["_type"]]
            begin
              obj = convert.call result["_id"]
              if obj.is_a? ElasticSearch::Model
                obj.es_document = result["_source"]
              end
              obj
            rescue
              nil
            end
          else
            result
          end
        end.compact
      @processed = true
    end

  end

end

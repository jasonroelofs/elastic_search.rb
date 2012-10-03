module ElasticSearch
  ##
  # This object takes care of building up the internal ES representation
  # of a search request
  ##
  class Query

    ##
    # Specify what page this search query needs to return
    # results from.
    ##
    attr_accessor :current_page

    ##
    # Specify how big a page is.
    ##
    attr_accessor :page_size

    attr_reader :filters, :sort_fields

    ##
    # Add a query string to the request
    ##
    attr_accessor :query

    def initialize
      @query = nil
      @sort_fields = []
      @filters = []
      @page_size = 10
    end

    ##
    # Return a Hash that represents the request body
    ##
    def body
      return @final if @final

      @final = {}
      @final.merge! query_body  if @query && @query.any?
      @final.merge! sort_body
      @final.merge! filter_body if @filters.any?

      @final[:from] = (@current_page - 1) * @page_size if @current_page
      @final[:size] = @page_size if @page_size

      @final[:explain] = true

      @final
    end

    def current_page=(val)
      @current_page = val.to_i
    end

    def page_size=(val)
      @page_size = val.to_i
    end

    ##
    # Add a filter to the query.
    ##
    def filter_on(values)
      @filters << values
    end

    ##
    # Add a field and direction in which to sort the results.
    # Multiple sort fields can be added to a query and will be
    # processed in order added.
    #
    # _score is always added last to the query sorting list
    ##
    def add_sort_by(field, dir = "desc")
      @sort_fields << {field => dir}
    end

    protected

    def query_body
      {
        :query => {
          :query_string => {
            :query => @query
          }
        }
      }
    end

    def sort_body
      { :sort => (@sort_fields << "_score") }
    end

    def filter_body
      list = @filters.map {|f| {:term => f} }

      { :filter => { :and => list } }
    end

  end
end

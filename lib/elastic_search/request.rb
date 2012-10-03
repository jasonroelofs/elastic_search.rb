module ElasticSearch

  ##
  # Representation of a request to ElasticSearch. This object
  # consists of a path the request and the body to send down to ElasticSearch.
  ##
  class Request

    attr_reader :path, :body

    def initialize(path, body)
      @path = path
      @body = body
    end

    ##
    # Get a hash representation of all request information.
    #
    # This hash is then passed down to the job queue implementation
    # to handle async requests
    ##
    def to_hash
      {
        :path => self.path,
        :body => self.body
      }
    end

    ##
    # Given a hash, build a request.
    # This expects the hash to have two keys:
    #
    #  +:path+ and +:body+
    ##
    def self.from_hash(hash)
      Request.new(hash["path"] || hash[:path], hash["body"] || hash[:body])
    end

    def ==(request)
      return false if request.nil?
      request.path == self.path && request.body == self.body
    end

  end

end

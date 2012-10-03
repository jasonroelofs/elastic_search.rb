require 'httparty'
require 'multi_json'
require 'yajl'
require 'elastic_search/utils'

module ElasticSearch
  class Connection
    include HTTParty

    def put(request)
      self.class.put request.path, :body => MultiJson.encode(request.body)
    end

    def delete(request)
      self.class.delete request.path
    end
  end
end

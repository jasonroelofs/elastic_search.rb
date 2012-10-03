require 'resque'
require 'resque-loner'
require 'multi_json'
require 'yajl'

require 'elastic_search/request'

module ElasticSearch
  module DeferTo

    ##
    # Resque-based job queue for deferring ElasticSearch requests
    #
    # This implementation has two parts. On request it enqueues a
    # resque job under the Loner plugin to ensure only one of them
    # exist in the queue at any given time.
    #
    # This job then reads from a Redis set that contains all the
    # mapping information that needs to be passed down to ES for the
    # request.
    #
    # If a job is already in the queue or processing then this object
    # will simply add the mapping to the redis set.
    #
    # This job will use the redis connection already set on Resque itself.
    ##
    class Resque
      include ::Resque::Plugins::UniqueJob

      ##
      # Set up a new handler to listen on the passed in queue
      ##
      def initialize(resque_queue)
        self.class.instance_variable_set("@queue", resque_queue)
      end

      ##
      # Called from ElasticSearch.defer to set up async processing
      ##
      def enqueue(method, body)
        ::Resque.redis.rpush("elastic_search:#{method}", MultiJson.encode(body))

        # UniqueJob doesn't always clear out the redis key that it uses
        # to make sure only one job runs at a time. We check for that case
        # here and clean up the key if no worker is currently running
        if key = ::Resque.redis.keys("loners:*").first
          is_running =
            ::Resque::Worker.working.select do |worker|
              worker.queues.include? "search"
            end.any?

          ::Resque.redis.del(key) if !is_running
        end


        ::Resque.enqueue(ElasticSearch::DeferTo::Resque, method)
      end

      ##
      # Resque worker hook.
      #
      # Keep looping on the Redis set untl there are no more messages
      # to pop off.
      ##
      def self.perform(method)
        set_key = "elastic_search:#{method}"

        while body = ::Resque.redis.lpop(set_key)
          request = ElasticSearch::Request.from_hash MultiJson.decode(body)
          ElasticSearch.send(method, request)
        end
      end

    end

  end
end

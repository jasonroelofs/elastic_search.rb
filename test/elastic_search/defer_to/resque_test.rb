require 'test_helper_no_rails'
require 'elastic_search/defer_to/resque'

describe ElasticSearch::DeferTo::Resque do
  before do
    @redis = mock()
    ::Resque.stubs(:redis).returns(@redis)
    ::Resque.stubs(:redis_id).returns(1)
    @job_queue = ElasticSearch::DeferTo::Resque.new :elastic_search
  end

  it "takes the name of the queue to sit under" do
    ElasticSearch::DeferTo::Resque.instance_variable_get("@queue").must_equal :elastic_search
  end

  describe "#enqueue" do
    before do
      @redis.stubs(:keys).returns []
    end

    it "queues up the worker for the requested action" do
      ::Resque.expects(:enqueue).with(ElasticSearch::DeferTo::Resque, :index)
      @redis.stubs(:rpush)

      @job_queue.enqueue(:index, {:hash => "true"})
    end

    it "adds the mapping information to the redis set" do
      ::Resque.expects(:enqueue)
      @redis.expects(:rpush).with("elastic_search:index", MultiJson.encode({:hash => "true"}))

      @job_queue.enqueue(:index, {:hash => "true"})
    end

    describe "unique job loner key fix" do
      it "removes the stray loner key if one exists and no workers are running" do
        @redis.stubs(:rpush)
        @redis.stubs(:keys).returns ["key_found"]
        @redis.expects(:del).with "key_found"

        ::Resque.expects(:enqueue)
        ::Resque::Worker.expects(:working).returns([])

        @job_queue.enqueue(:index, {:hash => "true"})
      end

      it "leaves the key alone if a worker is found running" do
        @redis.stubs(:rpush)
        @redis.stubs(:keys).returns ["key_found"]
        @redis.expects(:del).never

        ::Resque.expects(:enqueue)
        ::Resque::Worker.expects(:working).returns(
          [stub(:queues => ["some_queue", "search"])])

        @job_queue.enqueue(:index, {:hash => "true"})

      end

    end
  end

  describe ".perform" do

    it "reads all message bodies from redis and processes them individually" do
      job1 = MultiJson.encode({:path => "path", :body => {:job => "1"}})
      job2 = MultiJson.encode({:path => "parth", :body => {:job => "2"}})

      @redis.expects(:lpop).with('elastic_search:index').
        returns(job1).then.returns(job2).then.returns(nil).times(3)

      ElasticSearch.expects(:index).with do |request|
        request.is_a?(ElasticSearch::Request)
      end.times(2)

      ElasticSearch::DeferTo::Resque.perform(:index)
    end

  end

end

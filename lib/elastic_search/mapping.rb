require 'elastic_search/request'

module ElasticSearch

  ##
  # Define specific type conversions to be performed when
  # a requested field must be a certain type
  ##
  TYPE_CONVERSIONS = {
    # Ensure the field is true or false, nothing else
    :boolean => lambda {|value| !! value }
  }

  class Field
    attr_reader :name

    def initialize(name, type, &block)
      @name = name

      case type
      when Proc
        @block = type
      else
        @type = type
        @block = block
      end
    end

    def map(object)
      value =
        if @block
          @block.call object
        else
          object.send name
        end

      @type ? TYPE_CONVERSIONS[@type].call(value) : value
    end
  end

  ##
  # This is the context in which an elastic_search block is called
  ##
  class Fields

    def initialize(&mapping_block)
      @fields = []
      @only_if = nil
      @type = nil

      instance_eval &mapping_block
    end

    ##
    # Define an individual field to be added to the ElasticSearch
    # document when indexed.
    #
    # +name+  - the name of the field, accessible through a method
    # +type+  - If the system can't properly figure out the type of
    #           the field, use a Ruby class to tell what type to be,
    #           such as Boolean, Date, or String
    # +block+ - For custom or calculation fields, or if you want to
    #           have a different name, you can give a #field a block.
    #           This block should take a single argument, the object
    #           being mapped, and return the value you want to have
    #           sent to ElasticSearch
    #
    # This method does work with either a ruby block or a lambda. All
    # of the following are valid:
    #
    #   # Just the fields
    #   field :name
    #
    #   field :active, :boolean
    #
    #   # Fields and block, no types
    #   field :calculated do |obj|
    #     obj.calculated
    #   end
    #
    #   field :calculated, lambda {|obj| obj.calculated }
    #
    #   # Field, type, and blocks
    #   field :calculated, :boolean, lambda {|obj| obj.calculated }
    #
    #   field :calculated, :boolean do |obj|
    #     obj.calculated
    #   end
    #
    ##
    def field(name, type = nil, &block)
      @fields << Field.new(name, type, &block)
    end

    ##
    # Specify a method or a lambda that is called to see if the
    # object in question should be mapped or not. If the block
    # in question returns false, the object will not be mapped
    # or sent to ElasticSearch
    ##
    def only_if(symbol_or_block)
      @only_if = symbol_or_block
    end

    ##
    # By default the type of the object as given to ElasticSearch is
    # the name of the class. If you want a different type string, specify
    # it with this method
    ##
    def type(name)
      @type = name
    end

    ##
    # Map the given object into an ElasticSearch::Request
    ##
    def build_request(index, object)
      ElasticSearch::Request.new(
        path(index, object),
        map(object)
      )
    end

    private

    def can_be_mapped?(object)
      return true unless @only_if

      case @only_if
      when Symbol
        object.send(@only_if)
      else
        @only_if.call(object)
      end
    end

    # Given an object, send it through all the known fields and build
    # up a hash that will be sent to ElasticSearch for processing
    def map(object)
      if can_be_mapped?(object)
        body = {}
        @fields.each do |field|
          body[field.name] = field.map object
        end
        body
      end
    end

    # Figure out the full ElasticSearch path for mapping this object
    def path(index, object)
      [
        "",
        index,
        @type || object.class.name,
        object.id
      ].join "/"
    end
  end

  ##
  # A mapping is defined by the user via ElasticSearch::Model#elastic_search.
  ##
  class Mapping

    ##
    # Define a new mapping, given an ElasticSearch index name and the block
    # to define how the object in question should be mapped
    ##
    def initialize(index, &mapping)
      @index = index
      @fields = []

      # Run the definitions, building up our field definitions
      @fields = Fields.new &mapping
    end

    ##
    # Given an object this mapping works on, build and return
    # a request containing all relevant information for an ElasticSearch request
    ##
    def build_request(object)
      @fields.build_request(@index, object)
    end

  end
end

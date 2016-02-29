module RailsAPI
  module Exceptions
    class Error < RuntimeError; end

    class HasManyRelationExists < Error
      attr_accessor :id
      def initialize(id)
        super("The relation to #{id} already exists.")
        @id = id
      end
    end

    class InvalidFieldValue < Error
      attr_accessor :field, :value
      def initialize(field, value)
        super("#{value} is not a valid value for #{field}.")
        @field = field
        @value = value
      end
    end

    class RecordNotFound < Error
      attr_accessor :id
      def initialize(id)
        super("The record identified by #{id} could not be found.")
        @id = id
      end
    end

    class RecordLocked < Error
      attr_accessor :message
      def initialize(message)
        super(message)
        @message = message
      end
    end

    class ValidationErrors < Error
      attr_reader :error_messages, :resource_relationships

      def initialize(resource)
        super('Validation Error(s)')
        @error_messages = resource.model_error_messages
        @resource_relationships = resource.class._relationships.keys
      end
    end

    class SaveFailed < Error
      def initialize
        super('Save failed or was cancelled')
      end
    end
  end
end

module RailsAPI
  module ResourceFields
    def self.included(base)
      base.class_eval do
        base.extend ClassMethods
      end
    end

    module ClassMethods
      # Override in your resource to filter the updatable keys
      def updatable_fields(_context = nil)
        _updatable_relationships | _attributes.keys - [:id]
      end

      # Override in your resource to filter the creatable keys
      def creatable_fields(_context = nil)
        _updatable_relationships | _attributes.keys
      end

      # Override in your resource to filter the sortable keys
      def sortable_fields(_context = nil)
        _attributes.keys
      end

      def fields
        _relationships.keys | _attributes.keys
      end
    end

    def replace_fields(field_data)
      change :replace_fields do
        _replace_fields(field_data)
      end
    end

    # Override this on a resource instance to override the fetchable keys
    def fetchable_fields
      self.class.fields
    end

    private

    def _replace_fields(field_data)
      field_data[:attributes].each do |attribute, value|
        begin
          send "#{attribute}=", value
          @save_needed = true
        rescue ArgumentError
          # :nocov: Will be thrown if an enum value isn't allowed for an enum. Currently not tested as enums are a rails 4.1 and higher feature
          raise RailsAPI::Exceptions::InvalidFieldValue.new(attribute, value)
          # :nocov:
        end
      end

      field_data[:to_one].each do |relationship_type, value|
        if value.nil?
          remove_to_one_link(relationship_type)
        else
          case value
            when Hash
              replace_polymorphic_to_one_link(relationship_type.to_s, value.fetch(:id), value.fetch(:type))
            else
              replace_to_one_link(relationship_type, value)
          end
        end
      end if field_data[:to_one]

      field_data[:to_many].each do |relationship_type, values|
        replace_to_many_links(relationship_type, values)
      end if field_data[:to_many]

      :completed
    end
  end
end

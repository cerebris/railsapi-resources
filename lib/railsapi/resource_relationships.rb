require 'railsapi/relationship'

module RailsAPI
  module ResourceRelationships
    def self.included(base)
      base.class_eval do
        base.extend ClassMethods
      end
    end

    module ClassMethods
      attr_accessor :_relationships

      def relationship(*attrs)
        options = attrs.extract_options!
        klass = case options[:to]
                  when :one
                    Relationship::ToOne
                  when :many
                    Relationship::ToMany
                  else
                    #:nocov:#
                    fail ArgumentError.new('to: must be either :one or :many')
                  #:nocov:#
                end
        _add_relationship(klass, *attrs, options.except(:to))
      end

      def has_one(*attrs)
        _add_relationship(Relationship::ToOne, *attrs)
      end

      def has_many(*attrs)
        _add_relationship(Relationship::ToMany, *attrs)
      end

      def _updatable_relationships
        @_relationships.map { |key, _relationship| key }
      end

      def resolve_relationship_names_to_relations(resource_klass, model_includes, options = {})
        case model_includes
          when Array
            return model_includes.map do |value|
              resolve_relationship_names_to_relations(resource_klass, value, options)
            end
          when Hash
            model_includes.keys.each do |key|
              relationship = resource_klass._relationships[key]
              value = model_includes[key]
              model_includes.delete(key)
              model_includes[relationship.relation_name(options)] = resolve_relationship_names_to_relations(relationship.resource_klass, value, options)
            end
            return model_includes
          when Symbol
            relationship = resource_klass._relationships[model_includes]
            return relationship.relation_name(options)
        end
      end

      def _relationship(type)
        type = type.to_sym
        @_relationships[type]
      end

      def _add_relationship(klass, *attrs)
        options = attrs.extract_options!
        options[:parent_resource] = self

        attrs.each do |attr|
          relationship_name = attr.to_sym

          check_reserved_relationship_name(relationship_name)

          # Initialize from an ActiveRecord model's properties
          if is_active_record_model?
            model_association = _model_class.reflect_on_association(relationship_name)
            if model_association
              options[:class_name] ||= model_association.class_name
            end
          end

          @_relationships[relationship_name] = relationship = klass.new(relationship_name, options)

          foreign_key = relationship.foreign_key

          define_method "#{foreign_key}=" do |value|
            @model.method("#{foreign_key}=").call(value)
          end unless method_defined?("#{foreign_key}=")

          # Resources for relationships are returned through the dynamically generated method named for the
          # relationship (for example `has_many :comments` will create a method named `comments` on the resource).  This
          # method must return a single Resource for a `has_one` and an array of Resources for a `has_many`
          # relationship.
          #
          # In addition ActiveRecord Relation records for each relationship are retrieved through a dynamically
          # generated method named for the relationship (`record(s)_for_<relationship_name>). This in turn calls
          # the standard `records_for` method, which can be overridden for common code related to retrieving related
          # records.

          associated_records_method_name = case relationship
                                             when RailsAPI::Relationship::ToOne then "record_for_#{relationship_name}"
                                             when RailsAPI::Relationship::ToMany then "records_for_#{relationship_name}"
                                           end

          define_method associated_records_method_name do |options = {}|
            records_for_relationship(relationship_name, options)
          end unless method_defined?(associated_records_method_name)

          if relationship.is_a?(RailsAPI::Relationship::ToOne)
            if relationship.belongs_to?
              define_method foreign_key do
                @model.method(foreign_key).call
              end unless method_defined?(foreign_key)

              define_method relationship_name do |options = {}|
                relationship = self.class._relationships[relationship_name]

                if relationship.polymorphic?
                  associated_model = public_send(associated_records_method_name)
                  resource_klass = self.class.resource_for_model(associated_model) if associated_model
                  return resource_klass.new(associated_model, @context) if resource_klass
                else
                  resource_klass = relationship.resource_klass
                  if resource_klass
                    associated_model = public_send(associated_records_method_name)
                    return associated_model ? resource_klass.new(associated_model, @context) : nil
                  end
                end
              end unless method_defined?(relationship_name)
            else
              define_method foreign_key do
                relationship = self.class._relationships[relationship_name]

                record = public_send(associated_records_method_name)
                return nil if record.nil?
                record.public_send(relationship.resource_klass._primary_key)
              end unless method_defined?(foreign_key)

              define_method relationship_name do |options = {}|
                relationship = self.class._relationships[relationship_name]

                resource_klass = relationship.resource_klass
                if resource_klass
                  associated_model = public_send(associated_records_method_name)
                  return associated_model ? resource_klass.new(associated_model, @context) : nil
                end
              end unless method_defined?(relationship_name)
            end
          elsif relationship.is_a?(RailsAPI::Relationship::ToMany)
            define_method foreign_key do
              records = public_send(associated_records_method_name)
              return records.collect do |record|
                record.public_send(relationship.resource_klass._primary_key)
              end
            end unless method_defined?(foreign_key)

            define_method relationship_name do |options = {}|
              relationship = self.class._relationships[relationship_name]

              resource_klass = relationship.resource_klass

              records = public_send(associated_records_method_name, options)

              return records.collect do |record|
                if relationship.polymorphic?
                  resource_klass = self.class.resource_for_model(record)
                end
                resource_klass.new(record, @context)
              end
            end unless method_defined?(relationship_name)
          end
        end
      end

      private

      def check_reserved_relationship_name(name)
        if [:id, :ids, :type, :types].include?(name.to_sym)
          warn "[NAME COLLISION] `#{name}` is a reserved relationship name in #{_resource_name_from_type(_type)}."
        end
      end
    end

    def create_to_many_links(relationship_type, relationship_key_values)
      change :create_to_many_link do
        _create_to_many_links(relationship_type, relationship_key_values)
      end
    end

    def replace_to_many_links(relationship_type, relationship_key_values)
      change :replace_to_many_links do
        _replace_to_many_links(relationship_type, relationship_key_values)
      end
    end

    def replace_to_one_link(relationship_type, relationship_key_value)
      change :replace_to_one_link do
        _replace_to_one_link(relationship_type, relationship_key_value)
      end
    end

    def replace_polymorphic_to_one_link(relationship_type, relationship_key_value, relationship_key_type)
      change :replace_polymorphic_to_one_link do
        _replace_polymorphic_to_one_link(relationship_type, relationship_key_value, relationship_key_type)
      end
    end

    def remove_to_many_link(relationship_type, key)
      change :remove_to_many_link do
        _remove_to_many_link(relationship_type, key)
      end
    end

    def remove_to_one_link(relationship_type)
      change :remove_to_one_link do
        _remove_to_one_link(relationship_type)
      end
    end

    # Override this on a resource to customize how the associated records
    # are fetched for a model. Particularly helpful for authorization.
    def records_for(relation_name)
      _model.public_send relation_name
    end

    def records_for_relationship(relationship_name, _options = {})
      relationship = self.class._relationships[relationship_name]
      relation_name = relationship.relation_name(context: @context)
      records_for(relation_name)
    end

    private
    def _create_to_many_links(relationship_type, relationship_key_values)
      relationship = self.class._relationships[relationship_type]

      relationship_key_values.each do |relationship_key_value|
        related_resource = relationship.resource_klass.find_by_key(relationship_key_value, context: @context)

        relation_name = relationship.relation_name(context: @context)
        # TODO: Add option to skip relations that already exist instead of returning an error?
        relation = @model.public_send(relation_name).where(relationship.primary_key => relationship_key_value).first
        if relation.nil?
          @model.public_send(relation_name) << related_resource._model
        else
          fail RailsAPI::Exceptions::HasManyRelationExists.new(relationship_key_value)
        end
      end

      :completed
    end

    def _replace_to_many_links(relationship_type, relationship_key_values)
      relationship = self.class._relationships[relationship_type]
      send("#{relationship.foreign_key}=", relationship_key_values)
      @save_needed = true

      :completed
    end

    def _replace_to_one_link(relationship_type, relationship_key_value)
      relationship = self.class._relationships[relationship_type]

      send("#{relationship.foreign_key}=", relationship_key_value)
      @save_needed = true

      :completed
    end

    def _replace_polymorphic_to_one_link(relationship_type, key_value, key_type)
      relationship = self.class._relationships[relationship_type.to_sym]

      _model.public_send("#{relationship.foreign_key}=", key_value)
      _model.public_send("#{relationship.polymorphic_type}=", key_type.to_s.classify)

      @save_needed = true

      :completed
    end

    def _remove_to_many_link(relationship_type, key)
      relation_name = self.class._relationships[relationship_type].relation_name(context: @context)

      @model.public_send(relation_name).delete(key)

      :completed
    end

    def _remove_to_one_link(relationship_type)
      relationship = self.class._relationships[relationship_type]

      send("#{relationship.foreign_key}=", nil)
      @save_needed = true

      :completed
    end
  end
end
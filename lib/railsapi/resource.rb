require 'railsapi/resource_callbacks'
require 'railsapi/resource_relationships'
require 'railsapi/resource_attributes'
require 'railsapi/resource_fields'
require 'railsapi/resource_records'

module RailsAPI
  class Resource
    include ResourceCallbacks
    include ResourceRelationships
    include ResourceAttributes
    include ResourceFields
    include ResourceRecords

    attr_reader :context

    define_resource_callbacks :create,
                              :update,
                              :remove,
                              :save,
                              :create_to_many_link,
                              :replace_to_many_links,
                              :create_to_one_link,
                              :replace_to_one_link,
                              :replace_polymorphic_to_one_link,
                              :remove_to_many_link,
                              :remove_to_one_link,
                              :replace_fields

    def initialize(model, context)
      @model = model
      @context = context
    end

    def _model
      @model
    end

    def id
      _model.public_send(self.class._primary_key)
    end

    def is_new?
      id.nil?
    end

    def change(callback)
      completed = false

      if @changing
        run_callbacks callback do
          completed = (yield == :completed)
        end
      else
        run_callbacks is_new? ? :create : :update do
          @changing = true
          run_callbacks callback do
            completed = (yield == :completed)
          end

          completed = (save == :completed) if @save_needed || is_new?
        end
      end

      return completed ? :completed : :accepted
    end

    def remove
      run_callbacks :remove do
        _remove
      end
    end

    def save
      run_callbacks :save do
        _save
      end
    end

    def model_error_messages
      _model.errors.messages
    end

    private

    # Override this on a resource to return a different result code. Any
    # value other than :completed will result in operations returning
    # `:accepted`
    #
    # For example to return `:accepted` if your model does not immediately
    # save resources to the database you could override `_save` as follows:
    #
    # ```
    # def _save
    #   super
    #   return :accepted
    # end
    # ```
    def _save
      unless @model.valid?
        fail RailsAPI::Exceptions::ValidationErrors.new(self)
      end

      if defined? @model.save
        saved = @model.save(validate: false)
        unless saved
          if @model.errors.present?
            fail RailsAPI::Exceptions::ValidationErrors.new(self)
          else
            fail RailsAPI::Exceptions::SaveFailed.new
          end
        end
      else
        saved = true
      end

      @save_needed = !saved

      :completed
    end

    def _remove
      unless @model.destroy
        fail RailsAPI::Exceptions::ValidationErrors.new(self)
      end
      :completed
    end

    class << self
      public

      attr_accessor :_model_hints, :_type

      def inherited(subclass)
        subclass.abstract(false)
        subclass.immutable(false)
        subclass._attributes = (_attributes || {}).dup
        subclass._model_hints = (_model_hints || {}).dup

        subclass._relationships = {}
        # Add the relationships from the base class to the subclass using the original options
        if _relationships.is_a?(Hash)
          _relationships.each_value do |relationship|
            options = relationship.options.dup
            options[:parent_resource] = subclass
            subclass._add_relationship(relationship.class, relationship.name, options)
          end
        end

        type = subclass.name.demodulize.sub(/Resource$/, '').underscore
        subclass._type = type.pluralize.to_sym

        subclass.attribute :id, format: :id

        check_reserved_resource_name(subclass._type, subclass.name)
      end

      def resource_for(type)
        type_with_module = type.include?('/') ? type : module_path + type

        resource_name = _resource_name_from_type(type_with_module)
        resource = resource_name.safe_constantize if resource_name
        if resource.nil?
          fail NameError, "RailsAPI: Could not find resource '#{type}'. (Class #{resource_name} not found)"
        end
        resource
      end

      def resource_for_model(model)
        resource_for(resource_type_for(model))
      end

      def _resource_name_from_type(type)
        "#{type.to_s.underscore.singularize}_resource".camelize
      end

      def resource_type_for(model)
        model_name = model.class.to_s.underscore
        if _model_hints[model_name]
          _model_hints[model_name]
        else
          model_name.rpartition('/').last
        end
      end

      def routing_options(options)
        @_routing_resource_options = options
      end

      def routing_resource_options
        @_routing_resource_options ||= {}
      end

      def model_name(model, options = {})
        @_model_name = model.to_sym

        model_hint(model: @_model_name, resource: self) unless options[:add_model_hint] == false
      end

      def model_hint(model: _model_name, resource: _type)
        model_name = ((model.is_a?(Class)) && (model < ActiveRecord::Base)) ? model.name : model
        resource_type = ((resource.is_a?(Class)) && (resource < RailsAPI::Resource)) ? resource._type : resource.to_s

        _model_hints[model_name.to_s.gsub('::', '/').underscore] = resource_type.to_s
      end

      def create(context)
        new(create_model, context)
      end

      def create_model
        _model_class.new
      end

      def primary_key(key)
        @_primary_key = key.to_sym
      end

      def key_type(key_type)
        @_resource_key_type = key_type
      end

      def resource_key_type
        @_resource_key_type ||= :integer
      end

      def verify_key(key, context = nil)
        key_type = resource_key_type

        case key_type
        when :integer
          return if key.nil?
          Integer(key)
        when :string
          return if key.nil?
          if key.to_s.include?(',')
            raise RailsAPI::Exceptions::InvalidFieldValue.new(:id, key)
          else
            key
          end
        when :uuid
          return if key.nil?
          if key.to_s.match(/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/)
            key
          else
            raise RailsAPI::Exceptions::InvalidFieldValue.new(:id, key)
          end
        else
          key_type.call(key, context)
        end
      rescue
        raise RailsAPI::Exceptions::InvalidFieldValue.new(:id, key)
      end

      # override to allow for key processing and checking
      def verify_keys(keys, context = nil)
        return keys.collect do |key|
          verify_key(key, context)
        end
      end

      def _model_name
        _abstract ? '' : @_model_name ||= name.demodulize.sub(/Resource$/, '')
      end

      def _primary_key
        @_primary_key ||= _model_class.respond_to?(:primary_key) ? _model_class.primary_key : :id
      end

      def _as_parent_key
        @_as_parent_key ||= "#{_type.to_s.singularize}_id"
      end

      def abstract(val = true)
        @abstract = val
      end

      def _abstract
        @abstract
      end

      def immutable(val = true)
        @immutable = val
      end

      def _immutable
        @immutable
      end

      def mutable?
        !@immutable
      end

      def _model_class
        return nil if _abstract

        return @model if @model
        @model = _model_name.to_s.safe_constantize
        warn "[MODEL NOT FOUND] Model could not be found for #{self.name}. If this a base Resource declare it as abstract." if @model.nil?
        @model
      end

      def module_path
        if name == 'RailsAPI::Resource'
          ''
        else
          name =~ /::[^:]+\Z/ ? ($`.freeze.gsub('::', '/') + '/').underscore : ''
        end
      end

      private

      def is_active_record_model?
        _model_class && _model_class.ancestors.collect{|ancestor| ancestor.name}.include?('ActiveRecord::Base')
      end

      def check_reserved_resource_name(type, name)
        if [:ids, :types, :hrefs, :links].include?(type)
          warn "[NAME COLLISION] `#{name}` is a reserved resource name."
          return
        end
      end
    end
  end
end

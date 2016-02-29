module RailsAPI
  module ResourceAttributes
    def self.included(base)
      base.class_eval do
        base.extend ClassMethods
      end
    end

    module ClassMethods
      attr_accessor :_attributes

      def attributes(*attrs)
        options = attrs.extract_options!.dup
        attrs.each do |attr|
          attribute(attr, options)
        end
      end

      def attribute(attr, options = {})
        check_reserved_attribute_name(attr)

        if (attr.to_sym == :id) && (options[:format].nil?)
          ActiveSupport::Deprecation.warn('Id without format is no longer supported. Please remove ids from attributes, or specify a format.')
        end

        @_attributes ||= {}
        @_attributes[attr] = options
        define_method attr do
          @model.public_send(attr)
        end unless method_defined?(attr)

        define_method "#{attr}=" do |value|
          @model.public_send "#{attr}=", value
        end unless method_defined?("#{attr}=")
      end

      def _attribute_options(attr)
        default_attribute_options.merge(@_attributes[attr])
      end

      def default_attribute_options
        { format: :default }
      end

      private

      def check_reserved_attribute_name(name)
        # Allow :id since it can be used to specify the format. Since it is a method on the base Resource
        # an attribute method won't be created for it.
        if [:type].include?(name.to_sym)
          warn "[NAME COLLISION] `#{name}` is a reserved key in #{_resource_name_from_type(_type)}."
        end
      end
    end
  end
end

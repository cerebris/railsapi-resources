require 'active_support/callbacks'

module RailsAPI
  module ResourceCallbacks
    def self.included(base)
      base.class_eval do
        include ActiveSupport::Callbacks
        base.extend ClassMethods
      end
    end

    module ClassMethods
      def define_resource_callbacks(*callbacks)
        options = callbacks.extract_options!
        options = {
          only: [:before, :around, :after]
        }.merge!(options)

        types = Array(options.delete(:only))

        callbacks.each do |callback|
          define_callbacks(callback, options)

          types.each do |type|
            send("_define_#{type}_callback", self, callback)
          end
        end
      end

      private

      def _define_before_callback(klass, callback) #:nodoc:
        klass.define_singleton_method("before_#{callback}") do |*args, &block|
          set_callback(:"#{callback}", :before, *args, &block)
        end
      end

      def _define_around_callback(klass, callback) #:nodoc:
        klass.define_singleton_method("around_#{callback}") do |*args, &block|
          set_callback(:"#{callback}", :around, *args, &block)
        end
      end

      def _define_after_callback(klass, callback) #:nodoc:
        klass.define_singleton_method("after_#{callback}") do |*args, &block|
          set_callback(:"#{callback}", :after, *args, &block)
        end
      end
    end
  end
end
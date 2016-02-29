module RailsAPI
  module ResourceRecords
    def self.included(base)
      base.class_eval do
        base.extend ClassMethods
      end
    end

    module ClassMethods
      def apply_includes(records, _options = {})
        records
      end

      def apply_pagination(records, _options = {})
        records
      end

      def apply_sort(records, _options = {})
        records
      end

      def apply_filters(records, _options = {})
        records
      end
    end
  end
end
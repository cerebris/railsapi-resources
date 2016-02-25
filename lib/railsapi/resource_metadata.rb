module Railsapi
  module ResourceMetadata
    # Add metadata to validation error objects.
    #
    # Suppose `model_error_messages` returned the following error messages
    # hash:
    #
    #   {password: ["too_short", "format"]}
    #
    # Then to add data to the validation error `validation_error_metadata`
    # could return:
    #
    #   {
    #     password: {
    #       "too_short": {"minimum_length" => 6},
    #       "format": {"requirement" => "must contain letters and numbers"}
    #     }
    #   }
    #
    # The specified metadata is then be merged into the validation error
    # object.
    def validation_error_metadata
      {}
    end

    # Override this to return resource level meta data
    # must return a hash, and if the hash is empty the meta section will not be serialized with the resource
    # meta keys will be not be formatted with the key formatter for the serializer by default. They can however use the
    # serializer's format_key and format_value methods if desired
    # the _options hash will contain the serializer and the serialization_options
    def meta(_options)
      {}
    end
  end

end

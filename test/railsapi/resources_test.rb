require File.expand_path('../../test_helper', __FILE__)

class RailsAPI::ResourcesTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::RailsAPI::Resources::VERSION
  end
end
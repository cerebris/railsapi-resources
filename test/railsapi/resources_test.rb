require File.expand_path('../../test_helper', __FILE__)

class Railsapi::ResourcesTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Railsapi::Resources::VERSION
  end
end
require 'simplecov'

# To run tests with coverage:
# COVERAGE=true bundle exec rake test
# To Switch rails versions and run a particular test order:
# export RAILS_VERSION=4.2.0; bundle update rails; bundle exec rake TESTOPTS="--seed=39333" test
# We are no longer having Travis test Rails 4.0.x. To test on Rails 4.0.x use this:
# export RAILS_VERSION=4.2.5; bundle update rails; bundle exec rake test
# export RAILS_VERSION=5.0.0.beta1.1; bundle update rails; bundle exec rake test

if ENV['COVERAGE']
  SimpleCov.start do
  end
end

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'railsapi-resources'

require 'rails/all'
require 'rails/test_help'
require 'minitest/mock'
require 'minitest/autorun'

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.uncountable 'preferences'
  inflect.irregular 'numero_telefone', 'numeros_telefone'
end

Rails.env = 'test'

puts "Testing With RAILS VERSION #{Rails.version}"

class TestApp < Rails::Application
  config.eager_load = false
  config.root = File.dirname(__FILE__)
  config.session_store :cookie_store, key: 'session'
  config.secret_key_base = 'secret'

  #Raise errors on unsupported parameters
  config.action_controller.action_on_unpermitted_parameters = :raise

  ActiveRecord::Schema.verbose = false
  config.active_record.schema_format = :none
  config.active_support.test_order = :random

  # Turn off millisecond precision to maintain Rails 4.0 and 4.1 compatibility in test results
  ActiveSupport::JSON::Encoding.time_precision = 0 if Rails::VERSION::MAJOR >= 4 && Rails::VERSION::MINOR >= 1

  if Rails::VERSION::MAJOR >= 5
    config.active_support.halt_callback_chains_on_return_false = false
    config.active_record.time_zone_aware_types = [:time, :datetime]
  end
end

TestApp.initialize!

require File.expand_path('../fixtures/models', __FILE__)
require File.expand_path('../fixtures/resources', __FILE__)

class Minitest::Test
  include ActiveRecord::TestFixtures

  def run_in_transaction?
    true
  end

  self.fixture_path = "#{Rails.root}/fixtures"
  fixtures :all
end

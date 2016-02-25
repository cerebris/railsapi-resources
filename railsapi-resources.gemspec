# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'railsapi/resources/version'

Gem::Specification.new do |spec|
  spec.name          = 'railsapi-resources'
  spec.version       = Railsapi::Resources::VERSION
  spec.authors       = ['Dan Gebhardt', 'Larry Gebhardt']
  spec.email         = ['dan@cerebris.com', 'larry@cerebris.com']

  spec.summary       = 'A presenter layer for Rails APIs'
  spec.description   = 'A presenter layer for Rails APIs'
  spec.homepage      = 'https://github.com/cerebris/railsapi-resources'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  # if spec.respond_to?(:metadata)
  #   spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  # else
  #   raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  # end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.required_ruby_version = '>= 2.0'

  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'bundler', '~> 1.5'
  spec.add_development_dependency 'minitest-spec-rails'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'pry'
  spec.add_dependency 'rails', '>= 4.0'
end

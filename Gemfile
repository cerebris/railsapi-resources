source 'https://rubygems.org'

gemspec

platforms :ruby do
  gem 'sqlite3', '1.3.10'
end

platforms :jruby do
  gem 'activerecord-jdbcsqlite3-adapter'
end

version = ENV['RAILS_VERSION'] || 'default'

case version
  when 'master'
    gem 'rails', { git: 'https://github.com/rails/rails.git' }
    gem 'arel', { git: 'https://github.com/rails/arel.git' }
  when 'default'
    gem 'rails', '>= 4.2'
  else
    gem 'rails', "~> #{version}"
end

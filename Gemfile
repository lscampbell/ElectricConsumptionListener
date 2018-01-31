ruby '2.4.1'
source 'https://rubygems.org'

gem 'sneakers'
gem 'rest-client'
gem 'rb-readline'
gem 'dogstatsd-ruby'
gem 'activesupport'

group :development, :test do
  gem 'rspec'
  gem 'guard'
  gem 'guard-rspec'
  gem 'pry'
  if RUBY_PLATFORM=~ /win32/
  else
    gem 'rb-fsevent'
    gem 'growl'
  end
  gem 'rubocop-rspec'
end
source "https://rubygems.org"

gem "rails", "~> 7.2.2", ">= 7.2.2.1"
gem "sprockets-rails"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false

# Authentication & Authorization
gem "devise"
gem "pundit"

# Serialization
gem "active_model_serializers"

# Pagination
gem "kaminari"

# Password hashing
gem "bcrypt", "~> 3.1.7"


# UI
gem "bootstrap", "~> 5.3"
gem "dartsass-sprockets"
gem "haml-rails"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
end

group :development do
  gem "web-console"
  gem "annotate"
  gem "html2haml"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "shoulda-matchers", "~> 7.0"
  gem "rspec_junit_formatter"
end

gem "simplecov", "~> 0.22.0", :group => :test

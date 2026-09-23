source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3", ">= 8.1.3.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"
# json 3.0 dropped positional parse options that ActiveSupport::JSON.decode (Rails 8.1.3) still passes.
# Remove this pin once Rails supports json 3.
gem "json", "< 4"

# PostGIS adapter for spatial columns (households, groups, campuses) [https://github.com/rgeo/activerecord-postgis-adapter]
gem "activerecord-postgis-adapter", "~> 11.1"

# Background jobs; Solid Queue is intentionally not used [https://github.com/sidekiq/sidekiq]
gem "sidekiq", "~> 8.0"
# Recurring jobs (reminder sweep) on Sidekiq [https://github.com/sidekiq-cron/sidekiq-cron]
gem "sidekiq-cron", "~> 2.3"
# Redis client for the Rails cache store and the Action Cable adapter
gem "redis", ">= 5.0"

# Row-level multi-tenancy: scopes every church-owned model to Current.church
gem "acts_as_tenant", "~> 1.0"

# Authorization policies; every controller action is authorized
gem "pundit", "~> 2.4"

# has_secure_password for the Rails 8 authentication generator
gem "bcrypt", "~> 3.1.7"

# Pagination for the people list and audit log
gem "pagy", "~> 9.3"

# Address to point for households, groups, and campuses; provider chosen by ENV
gem "geocoder", "~> 1.8"

# CSV import of people (csv is no longer a default gem in Ruby 3.4)
gem "csv", "~> 3.3"

# Attendance reporting: weekly/monthly grouping in the church's zone, and charts
gem "groupdate", "~> 6.5"
gem "chartkick", "~> 5.1"

# Email: MJML compiled by MRML (Rust, no Node) via mjml-rails; Liquid for personalization and sections;
# Markdown (HTML escaped) for text sections
gem "mjml-rails", "~> 5.0"
gem "mrml", "~> 1.10"
gem "liquid", "~> 5.14"
gem "commonmarker", "~> 2.10"

# Email providers and audience sync, through their official SDKs
gem "postmark", "~> 1.25"
gem "aws-sdk-sesv2", "~> 1.110"
gem "aws-sdk-sns", "~> 1.121"
gem "mailchimp-marketing", "~> 0.0.218"

# Holidays that move attendance (Memorial Day, July 4th, Thanksgiving, ...). Easter is computed in code.
gem "holidays", "~> 8.8"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Test framework and factories
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails"

  # Realistic names and addresses for seeds and factories
  gem "faker"
end

group :test do
  gem "capybara"
  # Chrome over CDP for JavaScript system specs (drag and drop); no chromedriver needed
  gem "cuprite"
  # Blocks real network calls in specs
  gem "webmock"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # See sent emails (and click their links) at /letter_opener
  gem "letter_opener_web", "~> 3.0"
end

gem "ruby_native", "~> 0.17.3"

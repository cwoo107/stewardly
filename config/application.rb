require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Stewardly
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets middleware tasks]) # lib/middleware is required explicitly (config/environments)

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil
    config.generators do |g|
      g.test_framework :rspec, view_specs: false, helper_specs: false, routing_specs: false
      g.fixture_replacement :factory_bot, dir: "spec/factories"
    end

    # The domain that church subdomains hang off: grace.<app_domain>.
    # The bare app_domain serves the platform console.
    config.x.app_domain = ENV.fetch("APP_DOMAIN", "localhost")
    # "localhost" has 0 TLD parts after the domain, "stewardly.app" has 1, "stewardly.co.uk" has 2.
    config.action_dispatch.tld_length = config.x.app_domain.count(".")
    # The port links in emails use outside production (bin/dev serves on 3000).
    config.x.dev_port = ENV.fetch("PORT", 3000).to_i if Rails.env.development?

    # Church websites: grace.<sites_domain>, plus verified custom domains. A separate
    # domain from the admin app, so site pages (which run church-written Liquid) can never
    # read staff cookies. Custom domains CNAME to sites_cname_target; apex domains, which
    # can't have a CNAME, point A records at sites_apex_ips. TLS certificates are issued
    # on demand by the proxy in front of the app, which asks /internal/tls/allowed first.
    config.x.sites_domain = ENV.fetch("SITES_DOMAIN", "sites.#{config.x.app_domain}")
    config.x.sites_cname_target = ENV.fetch("SITES_CNAME_TARGET", "domains.#{config.x.sites_domain}")
    config.x.sites_apex_ips = ENV.fetch("SITES_APEX_IPS", "").split(",").map(&:strip).compact_blank
    config.x.tls_ask_token = ENV["TLS_ASK_TOKEN"]

    # Outgoing mail is sent from no-reply@<mail_domain>.
    config.x.mail_domain = ENV.fetch("MAIL_DOMAIN", config.x.app_domain == "localhost" ? "stewardly.test" : config.x.app_domain)

    config.active_job.queue_adapter = :sidekiq

    # Church mail goes through each church's provider (Email::ChurchDeliveryMethod); the
    # platform's own delivery is the fallback. Campaigns may use the platform fallback
    # only outside production.
    config.x.platform_delivery_method = :smtp
    config.x.platform_campaigns = !Rails.env.production?

    # A `time` column is a time of day on the wall clock (a service at 9:00, a group
    # at 19:00), not an instant, so it must not shift with Time.zone. Only datetimes
    # are converted.
    config.active_record.time_zone_aware_types = [ :datetime ]
  end
end

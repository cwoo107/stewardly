require "capybara/cuprite"

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [ 1400, 1000 ], process_timeout: 20, timeout: 10,
    headless: ENV["HEADLESS"] != "0", browser_options: { "no-sandbox" => nil })
end

# Church subdomains (grace.localhost) resolve to 127.0.0.1 in Chrome, so JS specs
# can use real hosts; the port is added to app_host automatically.
Capybara.server = :puma, { Silent: true }
Capybara.always_include_port = true
# Many compact controls are labelled with aria-label rather than a visible <label>.
Capybara.enable_aria_label = true

RSpec.configure do |config|
  config.before(type: :system, js: true) { driven_by :cuprite }
end

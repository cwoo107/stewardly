require "webmock/rspec"

# No real network calls from specs. Localhost stays open for Capybara/Cuprite.
WebMock.disable_net_connect!(allow_localhost: true)

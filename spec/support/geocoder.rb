# Specs never hit a geocoding provider: Geocoder's built-in test lookup returns stubs.
#   stub_geocoding("100 Main St, Nashville, TN 37203, US", latitude: 36.16, longitude: -86.78)
module GeocoderHelpers
  def stub_geocoding(address, latitude:, longitude:)
    Geocoder::Lookup::Test.add_stub(address, [ { "coordinates" => [ latitude, longitude ] } ])
  end
end

RSpec.configure do |config|
  config.include GeocoderHelpers

  config.before(:suite) do
    Geocoder.configure(lookup: :test, ip_lookup: :test)
  end

  config.before do
    Geocoder::Lookup::Test.reset
    Geocoder::Lookup::Test.set_default_stub([])
  end
end

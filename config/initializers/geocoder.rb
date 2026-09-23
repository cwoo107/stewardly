# Provider is chosen per deployment. Nominatim (the default) is fine for development,
# but its usage policy forbids bulk geocoding: use a commercial provider in production
# (e.g. GEOCODER_LOOKUP=mapbox or google with GEOCODER_API_KEY).
Geocoder.configure(
  lookup: ENV.fetch("GEOCODER_LOOKUP", "nominatim").to_sym,
  api_key: ENV["GEOCODER_API_KEY"],
  timeout: 5,
  units: :mi,
  # Raise instead of returning [] so GeocodeJob can retry transient failures.
  always_raise: :all,
  http_headers: { "User-Agent" => "Stewardly (#{ENV.fetch("GEOCODER_CONTACT_EMAIL", "geocoding@example.com")})" }
)

# Geocodes a Household, Group, or Campus after its address changes.
class GeocodeJob < ApplicationJob
  queue_as :low

  # Provider hiccups and rate limits are worth retrying; the lookup itself is idempotent.
  retry_on Geocoder::Error, Timeout::Error, SocketError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError

  def perform(record)
    record.geocode!
  end
end

# Sends a segment's people to the church's audience sync (e.g. Mailchimp).
class AudienceSyncJob < ApplicationJob
  queue_as :low

  def perform(segment)
    integration = Integration.active.find_by!(category: "email_audience_sync")
    count = integration.adapter.sync!(segment.people)
    integration.update!(settings: integration.settings.to_h.merge("last_synced_at" => Time.current.iso8601, "last_synced_count" => count.to_s))
  end
end

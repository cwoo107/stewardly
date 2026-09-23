# Applies a stored giving webhook. Safe to replay: the import is idempotent.
class Giving::WebhookProcessing
  def initialize(webhook_event)
    @webhook_event = webhook_event
    @integration = webhook_event.integration
  end

  def process!
    records = @integration.adapter.donations_from(@webhook_event)
    run = GivingSyncRun.create!(integration: @integration, kind: :webhook)
    counts = Giving::Import.new(@integration).import_donations(records)
    run.update!(status: :succeeded, finished_at: Time.current, created_count: counts.created, updated_count: counts.updated,
      matched_count: counts.matched, unmatched_count: counts.unmatched)
    @webhook_event.update!(status: :processed, processed_at: Time.current, error: nil)
  rescue Giving::Provider::Error, JSON::ParserError, KeyError, ArgumentError => error
    @webhook_event.update!(status: :failed, error: "#{error.class}: #{error.message}".first(1000))
  end
end

# Pulls funds and the last few days of donations from the provider, catching anything a
# webhook missed. Overlapping windows are fine: the import is idempotent.
class Giving::Reconciliation
  OVERLAP = 7.days

  def initialize(integration)
    @integration = integration
    @church = integration.church
  end

  def run!(kind: :reconcile, since: nil)
    since ||= (@integration.setting(:last_reconciled_on)&.then { |date| Date.iso8601(date) } || @church.today - 30) - OVERLAP
    run = GivingSyncRun.create!(integration: @integration, kind:, window_start: since, window_end: @church.today)
    import = Giving::Import.new(@integration)
    counts = Giving::Import::Counts.zero

    import.import_funds(adapter.funds)
    adapter.each_donation(since:, until: @church.today) { |page| import.import_donations(page, counts:) }

    run.update!(status: :succeeded, finished_at: Time.current, **count_attributes(counts))
    @integration.update!(settings: @integration.settings.to_h.merge("last_reconciled_on" => @church.today.iso8601))
    run
  rescue Giving::Provider::Error => error
    run&.update!(status: :failed, error: error.message.first(1000), finished_at: Time.current, **count_attributes(counts))
    run
  end

  private
    def adapter = @adapter ||= @integration.adapter

    def count_attributes(counts)
      return {} unless counts

      { created_count: counts.created, updated_count: counts.updated, matched_count: counts.matched, unmatched_count: counts.unmatched }
    end
end

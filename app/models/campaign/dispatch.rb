# Starts sending a campaign: saves the compiled HTML, creates one Delivery per
# recipient (insert-if-missing, so running twice adds no one), and queues batches.
class Campaign::Dispatch
  BATCH_SIZE = 100

  def initialize(campaign)
    @campaign = campaign
  end

  def dispatch!
    @campaign.with_lock do
      return unless @campaign.scheduled? || @campaign.sending?
      raise ArgumentError, @campaign.problems.to_sentence unless @campaign.ready?

      if @campaign.scheduled?
        tracking = Email::Tracking.new(@campaign.church) if @campaign.track_engagement?
        @campaign.update!(status: :sending, sending_at: Time.current,
          html_snapshot: EmailTemplate::Renderer.new(template).compile(tracking:))
      end
      create_deliveries
    end

    ids = @campaign.deliveries.queued.pluck(:id)
    ids.each_slice(BATCH_SIZE) { |batch| DeliveryBatchJob.perform_later(@campaign, batch) }
    @campaign.update!(status: :sent, sent_at: Time.current) if ids.empty? && @campaign.deliveries.sending.none?
  end

  private
    def template
      @campaign.email_template.dup.tap { |t| t.subject = @campaign.subject; t.preheader = @campaign.preheader.presence || t.preheader }
    end

    def create_deliveries
      now = Time.current
      rows = @campaign.audience.people.pluck(:id, :email).map do |person_id, email|
        { church_id: @campaign.church_id, campaign_id: @campaign.id, person_id:, email:, status: "queued",
          token: SecureRandom.base58(24), created_at: now, updated_at: now }
      end
      Delivery.insert_all(rows, unique_by: %i[ campaign_id person_id ]) if rows.any?
    end
end

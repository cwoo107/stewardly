# Sends up to 100 deliveries, then marks the campaign sent once nothing is left.
class DeliveryBatchJob < ApplicationJob
  queue_as :mailers

  def perform(campaign, delivery_ids)
    campaign.deliveries.where(id: delivery_ids).queued.includes(:person).find_each do |delivery|
      Delivery::Sending.new(delivery).send!
    end

    campaign.with_lock do
      if campaign.sending? && !campaign.deliveries.where(status: %w[ queued sending ]).exists?
        campaign.update!(status: :sent, sent_at: Time.current)
      end
    end
  end
end

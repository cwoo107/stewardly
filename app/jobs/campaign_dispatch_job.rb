# Creates a campaign's deliveries and queues their batches. Safe to run twice.
class CampaignDispatchJob < ApplicationJob
  queue_as :default

  def perform(campaign)
    Campaign::Dispatch.new(campaign).dispatch!
  end
end

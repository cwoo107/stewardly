# Applies a stored provider webhook (email events or giving). Replayable from the webhook log.
class IntegrationWebhookJob < ApplicationJob
  queue_as :default

  def perform(webhook_event)
    case webhook_event.integration.category
    when "email_delivery" then Email::EventProcessing.new(webhook_event).process!
    when "giving" then Giving::WebhookProcessing.new(webhook_event).process!
    else webhook_event.update!(status: :failed, error: "No processor for #{webhook_event.integration.category} webhooks")
    end
  end
end

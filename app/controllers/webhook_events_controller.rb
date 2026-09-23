# The webhook log: every provider webhook, stored raw, with replay.
class WebhookEventsController < ApplicationController
  def index
    authorize WebhookEvent
    @pagy, @events = pagy(policy_scope(WebhookEvent).includes(:integration).order(created_at: :desc))
  end

  def show
    @event = authorize WebhookEvent.find(params.expect(:id))
  end

  def replay
    event = authorize WebhookEvent.find(params.expect(:id))
    IntegrationWebhookJob.perform_later(event)
    redirect_to webhook_event_path(event), notice: "Replaying this webhook."
  end
end

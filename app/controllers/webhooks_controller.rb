# Provider webhooks (email delivery events, giving). The token in the URL finds the
# integration; the provider's own signature or credentials prove the request is real.
# The raw body is stored before anything else, then processed in a job (replayable).
class WebhooksController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection
  skip_after_action :verify_authorized # verified by the provider's signature below
  skip_around_action :use_church_time_zone

  rate_limit to: 600, within: 1.minute, with: -> { head :too_many_requests }

  def create
    integration = Integration.active.find_by(webhook_token: params.expect(:token).to_s)
    return head(:not_found) unless integration

    integration.adapter.verify_webhook!(request)
    event = integration.webhook_events.create!(provider: integration.provider, raw_body: request.raw_post,
      headers: request.headers.to_h.select { |key, _| key.start_with?("HTTP_X_", "CONTENT_TYPE") }.transform_values(&:to_s))
    IntegrationWebhookJob.perform_later(event)
    head :ok
  rescue Email::DeliveryProvider::InvalidWebhook, Giving::Provider::InvalidWebhook, NotImplementedError
    head :unauthorized
  end
end

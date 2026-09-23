# A provider webhook, stored exactly as received and processed in a job (so it can be replayed).
class WebhookEvent < ApplicationRecord
  belongs_to :integration
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  enum :status, { received: "received", processed: "processed", failed: "failed" }, default: :received, validate: true

  scope :recent_first, -> { order(created_at: :desc) }

  def payload = JSON.parse(raw_body)
end

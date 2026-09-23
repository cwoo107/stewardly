# Every AI call, logged for review: what was asked, what came back, and who asked.
class AiRequest < ApplicationRecord
  belongs_to :user, optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  enum :status, { pending: "pending", succeeded: "succeeded", failed: "failed" }, default: :pending, validate: true

  scope :recent_first, -> { order(created_at: :desc) }

  def self.tokens_used_since(time) = where(created_at: time..).sum("input_tokens + output_tokens")
end

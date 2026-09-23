# One pass of pulling donations from the provider (a webhook or the nightly reconciliation).
class GivingSyncRun < ApplicationRecord
  belongs_to :integration
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  enum :kind, { webhook: "webhook", reconcile: "reconcile", manual: "manual" }, validate: true
  enum :status, { running: "running", succeeded: "succeeded", failed: "failed" }, default: :running, validate: true

  scope :recent_first, -> { order(created_at: :desc) }
end

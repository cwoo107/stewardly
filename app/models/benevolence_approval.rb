# One person's decision on a case (approve with an amount, or deny). One per person per case.
class BenevolenceApproval < ApplicationRecord
  belongs_to :benevolence_case
  belongs_to :user
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  encrypts :note

  enum :decision, { approve: "approve", deny: "deny" }, validate: true

  validates :user_id, uniqueness: { scope: :benevolence_case_id, message: "has already decided on this case" }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }, if: :approve?
end

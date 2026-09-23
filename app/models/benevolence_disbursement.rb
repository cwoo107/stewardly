# Money paid out for a case: who was paid, how, from which fund. Once payments reach the
# approved amount the case is fulfilled.
class BenevolenceDisbursement < ApplicationRecord
  METHODS = { "check" => "Check", "card" => "Church card", "cash" => "Cash", "direct_payment" => "Direct payment", "gift_card" => "Gift card" }.freeze
  PAYEES = { "landlord" => "Landlord", "utility" => "Utility company", "person" => "The person", "vendor" => "Vendor or store", "other" => "Other" }.freeze

  belongs_to :benevolence_case
  belongs_to :fund, optional: true
  belongs_to :recorded_by, class_name: "User", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  encrypts :reference

  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :paid_on, :payee_name, presence: true
  validates :method, inclusion: { in: METHODS.keys }
  validates :payee_type, inclusion: { in: PAYEES.keys }
  validate :case_is_approved, on: :create
  validate :within_approved_amount, on: :create

  after_create :fulfil_when_paid

  def amount = Money.new(amount_cents, currency)

  private
    def case_is_approved
      errors.add(:base, "Only approved cases can be paid") unless benevolence_case&.approved?
    end

    def within_approved_amount
      return unless benevolence_case && amount_cents

      remaining = benevolence_case.remaining_cents
      errors.add(:amount_cents, "is more than the #{Money.format(remaining)} left on this case") if amount_cents > remaining
    end

    def fulfil_when_paid
      kase = benevolence_case
      kase.update!(status: :fulfilled, fulfilled_at: Time.current) if kase.disbursed_cents >= kase.approved_cents.to_i
      AuditEvent.record!(action: "benevolence.paid", auditable: kase, metadata: { "amount_cents" => amount_cents, "payee" => payee_type })
    end
end

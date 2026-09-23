# A request for financial help, linked to a person and their household. Private text
# is encrypted; every view is audited (BenevolenceCasesController).
class BenevolenceCase < ApplicationRecord
  NEEDS = { "rent" => "Rent or mortgage", "utilities" => "Utilities", "food" => "Food", "transportation" => "Transportation",
    "medical" => "Medical", "other" => "Other" }.freeze
  OPEN = %w[ submitted under_review approved ].freeze

  belongs_to :person
  belongs_to :household, optional: true
  belongs_to :form_submission, optional: true
  belongs_to :assigned_to, class_name: "User", optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :decided_by, class_name: "User", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_many :notes, -> { order(:created_at) }, class_name: "BenevolenceNote", dependent: :destroy
  has_many :approvals, class_name: "BenevolenceApproval", dependent: :destroy
  has_many :disbursements, -> { order(:paid_on, :id) }, class_name: "BenevolenceDisbursement", dependent: :restrict_with_error

  encrypts :summary, :circumstances, :decision_note

  enum :status, { submitted: "submitted", under_review: "under_review", approved: "approved", denied: "denied", fulfilled: "fulfilled" },
    default: :submitted, validate: true
  enum :source, { staff: "staff", form: "form" }, validate: true, prefix: true

  validates :need_category, inclusion: { in: NEEDS.keys }
  validates :requested_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :approved_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :summary, presence: true

  before_validation { self.household ||= person&.household }

  scope :open, -> { where(status: OPEN) }
  scope :recent_first, -> { order(created_at: :desc) }

  def open? = status.in?(OPEN)
  def need_label = NEEDS.fetch(need_category)
  def requested = Money.new(requested_cents, currency)
  def approved_amount = approved_cents && Money.new(approved_cents, currency)
  def disbursed_cents = disbursements.sum(:amount_cents)
  def remaining_cents = [ approved_cents.to_i - disbursed_cents, 0 ].max
  def title = "#{need_label} for #{person.name}"

  def policy_check = Benevolence::PolicyCheck.new(self)
  def decision = Benevolence::Decision.new(self)
end

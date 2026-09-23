# Every meaningful contact with a person. The person profile's timeline is built
# from these, and "no touchpoint in N days" segments and insights read them.
class Touchpoint < ApplicationRecord
  MANUAL_KINDS = %w[ note call visit text ].freeze

  belongs_to :person
  belongs_to :author, class_name: "User", optional: true
  belongs_to :subject, polymorphic: true, optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  enum :kind, { note: "note", call: "call", visit: "visit", text: "text", email: "email",
    prayer_follow_up: "prayer_follow_up", form_submission: "form_submission", workflow_message: "workflow_message" },
    validate: true

  encrypts :body

  validates :summary, presence: true, length: { maximum: 200 }
  validates :occurred_at, presence: true

  before_validation { self.occurred_at ||= Time.current }

  scope :recent_first, -> { order(occurred_at: :desc, id: :desc) }
end

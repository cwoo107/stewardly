class PrayerRequest < ApplicationRecord
  belongs_to :person, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :form_submission, optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_many :prayer_assignments, dependent: :delete_all
  has_many :assignees, through: :prayer_assignments, source: :user
  has_many :follow_ups, -> { recent_first }, class_name: "Touchpoint", as: :subject, dependent: :nullify

  # pastoral_staff: manage_prayer_requests only. prayer_team: also view_prayer_requests.
  # shared: will also appear in the member area (Phase 3).
  enum :visibility, { pastoral_staff: "pastoral_staff", prayer_team: "prayer_team", shared: "shared" },
    default: :pastoral_staff, validate: true
  enum :status, { active: "active", answered: "answered", archived: "archived" }, default: :active, validate: true
  enum :source, { staff: "staff", form: "form", member: "member" }, default: :staff, validate: true, prefix: true

  encrypts :body, :answer_note

  validates :body, presence: true
  validate :has_a_requester

  before_save { self.answered_at = answered? ? (answered_at || Time.current) : nil if status_changed? }

  scope :recent_first, -> { order(created_at: :desc) }
  scope :visible_to_prayer_team, -> { where(visibility: %w[ prayer_team shared ]) }

  def requester_display_name
    person&.name || requester_name
  end

  private
    def has_a_requester
      errors.add(:base, "Choose a person or enter the requester's name") if person_id.blank? && requester_name.blank?
    end
end

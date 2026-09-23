class Role < ApplicationRecord
  CHURCH_ADMIN = "church_admin"

  # Seeded into every church by Church::Provisioning. Ministry leaders are not a role:
  # leadership is granted per ministry through MinistryLeadership.
  DEFAULTS = [
    { key: CHURCH_ADMIN, name: "Church admin", grants_all: true },
    { key: "staff", name: "Staff",
      permissions: %w[ manage_announcements manage_courses manage_email manage_events manage_forms manage_ministries manage_pathways manage_people
        manage_schedules manage_tasks manage_workflows approve_messages manage_social manage_website use_reports view_insights record_attendance view_attendance view_form_submissions view_people view_precise_locations ] },
    { key: "care_team", name: "Care team", permissions: %w[ view_people view_prayer_requests ] },
    { key: "benevolence_team", name: "Benevolence team", permissions: %w[ manage_benevolence view_benevolence view_people ] },
    { key: "member", name: "Member", permissions: [] }
  ].freeze

  acts_as_tenant :church

  has_many :user_roles, dependent: :restrict_with_error
  has_many :users, through: :user_roles

  normalizes :permissions, with: ->(permissions) { permissions.compact_blank.uniq.sort }

  validates :name, presence: true
  validates :key, presence: true, format: { with: /\A[a-z][a-z0-9_]*\z/ }
  validates_uniqueness_to_tenant :key
  validate :permissions_are_known

  before_destroy :keep_system_roles

  scope :ordered, -> { order(grants_all: :desc, name: :asc) }

  def grants?(permission)
    grants_all? || permissions.include?(Permission.fetch(permission))
  end

  def church_admin?
    key == CHURCH_ADMIN
  end

  private
    def keep_system_roles
      return unless system?

      errors.add(:base, "Default roles can't be deleted")
      throw :abort
    end

    def permissions_are_known
      unknown = permissions - Permission.keys
      errors.add(:permissions, "include unknown keys: #{unknown.join(", ")}") if unknown.any?
    end
end

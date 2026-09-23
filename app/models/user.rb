class User < ApplicationRecord
  belongs_to :person
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles
  has_many :ministry_leaderships, dependent: :destroy
  has_many :led_ministries, through: :ministry_leaderships, source: :ministry
  has_many :prayer_assignments, dependent: :delete_all

  # Records this user authored outlive the account.
  with_options dependent: :nullify do
    has_many :owned_tasks, class_name: "Task", foreign_key: :owner_id, inverse_of: :owner
    has_many :created_tasks, class_name: "Task", foreign_key: :created_by_id, inverse_of: :created_by
    has_many :authored_touchpoints, class_name: "Touchpoint", foreign_key: :author_id, inverse_of: :author
    has_many :person_imports, foreign_key: :created_by_id, inverse_of: :created_by
    has_many :segments, foreign_key: :created_by_id, inverse_of: :created_by
    has_many :created_prayer_requests, class_name: "PrayerRequest", foreign_key: :created_by_id, inverse_of: :created_by
    has_many :duplicate_dismissals, foreign_key: :dismissed_by_id, inverse_of: :dismissed_by
  end

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates_uniqueness_to_tenant :email_address
  validates :person_id, uniqueness: true

  delegate :name, to: :person

  scope :alphabetical, -> { joins(:person).merge(Person.alphabetical) }

  after_destroy :audit_deletion

  def can?(permission)
    permission = Permission.fetch(permission)
    roles.any? { |role| role.grants?(permission) }
  end

  def church_admin?
    roles.any?(&:church_admin?)
  end

  # Admin screens are for anyone with a permission or a ministry to lead;
  # everyone else signs in to the member area.
  def admin_area?
    roles.any? { |role| role.grants_all? || role.permissions.any? } || leads_any_ministry?
  end

  def leads?(ministry)
    ministry.present? && led_ministry_ids.include?(ministry.id)
  end

  def leads_any_ministry?
    led_ministry_ids.any?
  end

  def led_ministry_ids
    @led_ministry_ids ||= ministry_leaderships.pluck(:ministry_id)
  end

  private
    def audit_deletion
      AuditEvent.record!(action: "user.deleted", auditable: self, metadata: { email_address:, person_id: })
    end
end

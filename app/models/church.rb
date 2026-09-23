class Church < ApplicationRecord
  # Subdomains the platform itself needs; a church can never claim them.
  RESERVED_SUBDOMAINS = %w[ admin api app assets cdn domains help mail platform sites status support www ].freeze
  AUDITED_SETTINGS = %w[ social_event_promos no_contact_days ai_private_totals benevolence_approval_threshold_cents benevolence_approvals_required benevolence_annual_limit_cents
    benevolence_limit_scope ai_enabled ai_monthly_token_cap workflow_daily_send_limit name time_zone group_coverage_miles contact_email giving_url reminder_days_before attendance_categories
    mailing_address email_from_domain ].freeze
  # Attendance categories with this name count as online; every other category is in person.
  ONLINE_CATEGORY = "Online"

  has_many :households, dependent: :destroy
  has_many :people, dependent: :destroy
  has_many :users, dependent: :destroy
  has_many :roles, dependent: :destroy
  has_many :audit_events, dependent: :delete_all
  has_many :campuses, dependent: :destroy
  has_one :pathway, dependent: :destroy

  normalizes :subdomain, with: ->(subdomain) { subdomain.strip.downcase }

  validates :name, presence: true
  validates :subdomain, presence: true, uniqueness: true, length: { maximum: 63 },
    format: { with: /\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/, message: "may only contain letters, numbers, and hyphens" },
    exclusion: { in: RESERVED_SUBDOMAINS, message: "is reserved" }
  validates :group_coverage_miles, numericality: { only_integer: true, in: 1..50 }
  validates :email_from_domain, format: { with: /\A[a-z0-9.-]+\.[a-z]{2,}\z/i, message: "must be a domain like gracechurch.org" }, allow_blank: true
  validates :benevolence_approval_threshold_cents, :benevolence_annual_limit_cents, numericality: { only_integer: true, in: 0..100_000_000 }
  validates :no_contact_days, numericality: { only_integer: true, in: 14..365 }
  validates :benevolence_approvals_required, inclusion: { in: [ 1, 2 ] }
  validates :benevolence_limit_scope, inclusion: { in: %w[ household person ] }
  validates :ai_monthly_token_cap, numericality: { only_integer: true, in: 0..100_000_000 }
  validates :workflow_daily_send_limit, numericality: { only_integer: true, in: 0..100_000 }
  validates :reminder_days_before, numericality: { only_integer: true, in: 1..14 }
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :giving_url, format: { with: %r{\Ahttps?://\S+\z}, message: "must be a web address" }, allow_blank: true
  validates :time_zone, presence: true, inclusion: { in: ->(_) { ActiveSupport::TimeZone.all.map(&:name) }, message: "is not a recognized time zone" }

  after_update :audit_settings_change, if: :saved_change_to_settings?

  def self.find_by_host_subdomain(subdomain)
    find_by(subdomain: subdomain) if subdomain.present?
  end

  normalizes :attendance_categories, with: ->(categories) { categories.map(&:squish).compact_blank.uniq }

  def self.online_category?(name) = name.to_s.casecmp?(ONLINE_CATEGORY)

  # Church settings merged over Volunteering::LoadAssessment::DEFAULT_THRESHOLDS.
  def load_thresholds
    Volunteering::LoadAssessment::DEFAULT_THRESHOLDS.merge(volunteer_load_thresholds.to_h.transform_values(&:to_f))
  end

  def email_integration = Integration.active.find_by(category: "email_delivery")

  # Campaign mail is sent from the church's own domain when it has one.
  def email_from_address
    email_from_domain.present? ? "hello@#{email_from_domain}" : "no-reply@#{Rails.configuration.x.mail_domain}"
  end

  def zone
    ActiveSupport::TimeZone[time_zone]
  end

  def now
    zone.now
  end

  def today
    zone.today
  end

  def host
    "#{subdomain}.#{Rails.configuration.x.app_domain}"
  end

  def site = Site.find_by(church: self)

  private
    def saved_change_to_settings?
      saved_changes.keys.intersect?(AUDITED_SETTINGS)
    end

    def audit_settings_change
      ActsAsTenant.with_tenant(self) do
        AuditEvent.record!(action: "church.settings_updated", auditable: self, metadata: saved_changes.slice(*AUDITED_SETTINGS))
      end
    end
end

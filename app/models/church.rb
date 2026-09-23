class Church < ApplicationRecord
  # Subdomains the platform itself needs; a church can never claim them.
  RESERVED_SUBDOMAINS = %w[ admin api app assets cdn help mail platform status support www ].freeze
  AUDITED_SETTINGS = %w[ name time_zone group_coverage_miles contact_email giving_url reminder_days_before attendance_categories ].freeze
  # Attendance categories with this name count as online; every other category is in person.
  ONLINE_CATEGORY = "Online"

  has_many :households, dependent: :destroy
  has_many :people, dependent: :destroy
  has_many :users, dependent: :destroy
  has_many :roles, dependent: :destroy
  has_many :audit_events, dependent: :delete_all
  has_many :campuses, dependent: :destroy

  normalizes :subdomain, with: ->(subdomain) { subdomain.strip.downcase }

  validates :name, presence: true
  validates :subdomain, presence: true, uniqueness: true, length: { maximum: 63 },
    format: { with: /\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/, message: "may only contain letters, numbers, and hyphens" },
    exclusion: { in: RESERVED_SUBDOMAINS, message: "is reserved" }
  validates :group_coverage_miles, numericality: { only_integer: true, in: 1..50 }
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

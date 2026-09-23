class Person < ApplicationRecord
  belongs_to :household, optional: true
  belongs_to :merged_into, class_name: "Person", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_one :user, dependent: :restrict_with_error
  has_many :taggings, dependent: :delete_all
  has_many :tags, through: :taggings
  has_many :touchpoints, dependent: :delete_all
  has_many :group_memberships, dependent: :delete_all
  has_many :groups, through: :group_memberships
  has_many :team_memberships, dependent: :delete_all
  has_many :teams, through: :team_memberships
  has_many :prayer_requests, dependent: :nullify
  has_many :assignments, dependent: :destroy
  has_many :blockouts, dependent: :delete_all
  has_many :position_qualifications, dependent: :delete_all
  has_many :registrations, dependent: :destroy
  has_many :enrollments, dependent: :destroy
  has_many :group_join_requests, dependent: :delete_all
  has_many :attendances, dependent: :delete_all
  has_many :email_preferences, dependent: :delete_all
  has_many :deliveries, dependent: :delete_all
  has_many :message_drafts, dependent: :delete_all
  has_many :donations, dependent: :nullify
  has_many :donor_links, dependent: :delete_all
  has_many :benevolence_cases, dependent: :restrict_with_error
  has_many :workflow_runs, dependent: :destroy
  has_one :pathway_placement, dependent: :delete
  has_many :pathway_transitions, -> { order(occurred_at: :desc, id: :desc) }, dependent: :delete_all
  # Records merged into this person are history of this person, so they go with it.
  has_many :merged_people, class_name: "Person", foreign_key: :merged_into_id, inverse_of: :merged_into, dependent: :destroy
  has_many :duplicate_dismissals, dependent: :delete_all
  has_many :reverse_duplicate_dismissals, class_name: "DuplicateDismissal", foreign_key: :other_person_id,
    inverse_of: :other_person, dependent: :delete_all

  enum :membership_status, { guest: "guest", regular_attender: "regular_attender", member: "member", inactive: "inactive" },
    default: :guest, validate: true
  enum :household_role, { adult: "adult", child: "child" }, default: :adult, validate: true

  normalizes :email, with: ->(email) { email.strip.downcase.presence }
  normalizes :phone, with: ->(phone) { phone.strip.presence }

  validates :first_name, :last_name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validate :custom_fields_match_definitions

  after_destroy :audit_deletion
  after_create_commit { Workflow::Events.publish("person_created", person: self, subject: self) }
  after_commit :place_on_pathway, on: :update, if: -> { saved_change_to_membership_status? }

  # Merged-away records stay for history but are hidden from every list and search.
  scope :unmerged, -> { where(merged_into_id: nil) }
  scope :alphabetical, -> { order(:last_name, :first_name) }
  scope :search, ->(term) {
    next all if term.blank?

    pattern = "%#{sanitize_sql_like(term.strip)}%"
    where("(people.first_name || ' ' || people.last_name) ILIKE :pattern OR people.email ILIKE :pattern " \
      "OR people.phone ILIKE :pattern OR people.nickname ILIKE :pattern", pattern:)
  }

  def name
    "#{nickname.presence || first_name} #{last_name}"
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def age(on: church.today)
    return unless birthdate

    on.year - birthdate.year - ([ on.month, on.day ] <=> [ birthdate.month, birthdate.day ]).clamp(-1, 0).abs
  end

  def merged?
    merged_into_id.present?
  end

  # The member area account link: invitations and self-claim use the same token,
  # which stops working once an account exists or the email changes.
  generates_token_for :account_setup, expires_in: 7.days do
    [ email, user&.id ]
  end

  # The email preference center link. Stays valid until the email address changes.
  generates_token_for :email_preferences do
    email
  end

  def blocked_out_on?(date)
    blockouts.any? { |blockout| blockout.covers?(date) }
  end

  def last_touchpoint_at
    touchpoints.maximum(:occurred_at)
  end

  # Casts and stores values for church-defined custom fields, keyed by CustomField#key.
  # Unknown keys are ignored; blank values remove the key.
  def custom_field_values=(values)
    definitions = CustomField.where(key: values.to_h.keys.map(&:to_s)).index_by(&:key)
    @custom_field_errors = []

    updated = custom_fields.dup
    values.to_h.each do |key, raw|
      field = definitions[key.to_s] or next
      value = field.cast(raw)
      value.nil? ? updated.delete(field.key) : updated[field.key] = value
    rescue CustomField::InvalidValue => error
      @custom_field_errors << "#{field.label} #{error.message}"
    end
    self.custom_fields = updated
  end

  def custom_field_value(field)
    custom_fields[field.key]
  end

  private
    def custom_fields_match_definitions
      Array(@custom_field_errors).each { |message| errors.add(:custom_fields, message) }
    end

    def place_on_pathway
      PathwayPlacementJob.perform_later(self)
    end

    def audit_deletion
      AuditEvent.record!(action: "person.deleted", auditable: self, metadata: { name: full_name, email: })
    end
end

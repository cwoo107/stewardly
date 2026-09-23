class Event < ApplicationRecord
  belongs_to :ministry, optional: true
  belongs_to :campus, optional: true
  belongs_to :organizer, class_name: "User", optional: true
  belongs_to :registration_form, class_name: "Form", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_many :occurrences, -> { order(:starts_at) }, class_name: "EventOccurrence", dependent: :destroy, inverse_of: :event
  has_many :registrations, through: :occurrences
  has_many :position_needs, as: :needable, dependent: :destroy

  # public: listed on the church's public pages and the member area; members: member area only;
  # internal: staff calendar only.
  enum :visibility, { public: "public", members: "members", internal: "internal" }, default: :public, validate: true, prefix: true
  enum :status, { draft: "draft", published: "published", cancelled: "cancelled" }, default: :draft, validate: true

  normalizes :slug, with: ->(slug) { slug.to_s.parameterize }
  before_validation { self.slug = title if slug.blank? && title.present? }

  validates :title, presence: true
  validates :slug, presence: true, format: { with: /\A[a-z0-9][a-z0-9-]*\z/ }
  validates_uniqueness_to_tenant :slug
  validates :capacity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :max_party_size, numericality: { only_integer: true, in: 1..20 }
  validate :registration_form_is_for_events

  scope :listed_for_members, -> { published.where(visibility: %w[ public members ]) }
  scope :alphabetical, -> { order(:title) }

  def registration_open?(now = Time.current)
    registration_required? && published? &&
      (registration_opens_at.nil? || now >= registration_opens_at) &&
      (registration_closes_at.nil? || now <= registration_closes_at)
  end

  def upcoming_occurrences(now = Time.current)
    occurrences.select { |occurrence| occurrence.ends_at > now && !occurrence.cancelled? }
  end

  def location_summary
    [ location_name, address_line1, city ].compact_blank.join(", ")
  end

  private
    def registration_form_is_for_events
      errors.add(:registration_form, "must be an event registration form") if registration_form && !registration_form.event_registration_form?
    end
end

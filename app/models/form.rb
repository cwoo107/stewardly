# A form staff build and the public (or, later, members) fill in at /f/:slug.
class Form < ApplicationRecord
  acts_as_tenant :church

  has_many :fields, -> { ordered }, class_name: "FormField", dependent: :destroy, inverse_of: :form
  has_many :submissions, class_name: "FormSubmission", dependent: :restrict_with_error, inverse_of: :form

  enum :status, { draft: "draft", published: "published", closed: "closed" }, default: :draft, validate: true
  # Benevolence intake (Phase 8) adds a purpose. Event registration forms are only
  # shown inside an event's registration, never at /f/:slug.
  enum :purpose, { general: "general", prayer_request: "prayer_request", event_registration: "event_registration" },
    default: :general, validate: true, suffix: :form
  # Members-only forms need a member area sign-in.
  enum :access, { public: "public", members: "members" }, default: :public, validate: true, prefix: true

  normalizes :slug, with: ->(slug) { slug.to_s.parameterize }

  before_validation { self.slug = name if slug.blank? && name.present? }

  validates :name, presence: true
  validates :slug, presence: true, format: { with: /\A[a-z0-9][a-z0-9-]*\z/ }
  validates_uniqueness_to_tenant :slug
  validate :ready_to_publish, if: -> { published? && status_changed? }

  scope :alphabetical, -> { order(:name) }

  def publish!
    update!(status: :published, published_at: published_at || Time.current)
  end

  def close!
    update!(status: :closed)
  end

  def field_for(maps_to)
    fields.find { |field| field.maps_to == maps_to }
  end

  # Rules keyed by field, as the browser needs them for show/hide.
  def visibility_rules
    fields.to_h { |field| [ field.key, field.visibility_rule ] }.compact_blank
  end

  private
    def ready_to_publish
      errors.add(:base, "Add at least one field before publishing") if fields.empty?
      if prayer_request_form? && field_for("prayer_request.body").nil?
        errors.add(:base, "A prayer request form needs a field that goes to the prayer request")
      end
    end
end

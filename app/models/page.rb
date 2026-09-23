# A page of a church website: an ordered list of sections, edited as a draft and
# published when ready. Visitors only ever see published_sections.
class Page < ApplicationRecord
  KINDS = %w[ home about events groups give contact custom ].freeze
  REVISIONS_KEPT = 20
  SLUG = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  # Paths the site itself uses (forms, events, tracking, assets, sitemap).
  RESERVED = %w[ f e t u webhooks internal rails assets sitemap robots me session up ].freeze

  belongs_to :site, inverse_of: :pages
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church
  include HasSections
  include Positionable

  has_sections :draft_sections, kind: "web"
  positioned within: :site_id

  has_many :revisions, -> { order(published_at: :desc) }, class_name: "PageRevision", dependent: :delete_all

  normalizes :slug, with: ->(slug) { slug.to_s.strip.downcase.parameterize }

  validates :title, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :slug, uniqueness: { scope: :site_id }
  validates :slug, format: { with: SLUG, message: "can only use letters, numbers, and dashes" }, unless: :home?
  validate :slug_isnt_reserved

  before_save { self.draft_updated_at = Time.current if draft_sections_changed? }

  def home? = slug.blank?
  def path = home? ? "/" : "/#{slug}"
  def published? = published_at.present?
  def unpublished_changes? = !published? || draft_sections != published_sections

  def publish!(by: Current.user)
    transaction do
      update!(published_sections: draft_sections, published_at: Time.current)
      revisions.create!(sections: draft_sections, published_by: by, published_at: Time.current)
      revisions.offset(REVISIONS_KEPT).each(&:destroy!)
    end
    site.expire_cache!
  end

  def unpublish!
    update!(published_sections: nil, published_at: nil)
    site.expire_cache!
  end

  def discard_draft! = update!(draft_sections: published_sections || [])
  def restore!(revision) = update!(draft_sections: revision.sections)

  private
    def slug_isnt_reserved
      errors.add(:slug, "is used by the site itself") if RESERVED.include?(slug.to_s.split("/").first)
    end
end

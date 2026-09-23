# An email design: an ordered list of sections, each a SectionDefinition key plus its
# settings, and a theme. The footer (address, unsubscribe, preferences) is always added.
class EmailTemplate < ApplicationRecord
  THEME_DEFAULTS = {
    "brand_color" => "#06b6d4", "background_color" => "#f3f4f6", "content_background" => "#ffffff",
    "text_color" => "#1f2937", "font_family" => "Helvetica, Arial, sans-serif"
  }.freeze
  FONTS = { "Helvetica, Arial, sans-serif" => "Helvetica", "Georgia, 'Times New Roman', serif" => "Georgia",
    "'Trebuchet MS', Arial, sans-serif" => "Trebuchet" }.freeze

  acts_as_tenant :church
  include HasSections

  has_sections :sections, kind: "email"

  has_many :campaigns, dependent: :restrict_with_error

  validates :name, presence: true

  scope :alphabetical, -> { order(:name) }

  def theme_settings = THEME_DEFAULTS.merge(theme.to_h.compact_blank)
end

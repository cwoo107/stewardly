# A reusable building block for templates: Liquid that produces MJML (email) or HTML
# (website, Phase 10), plus a schema describing its settings. Built-ins are installed
# per church from app/sections so churches can customise them later.
class SectionDefinition < ApplicationRecord
  SETTING_TYPES = %w[ text textarea markdown url color select number image checkbox form ].freeze

  acts_as_tenant :church

  enum :kind, { email: "email", web: "web" }, validate: true, prefix: true

  validates :key, presence: true, format: { with: /\A[a-z][a-z0-9_]*\z/ }, uniqueness: { scope: %i[ church_id kind ] }
  validates :name, :liquid, presence: true
  validate :liquid_parses
  validate :schema_is_valid

  scope :ordered, -> { order(:position, :name) }

  def settings_schema = Array(schema["settings"])
  def blocks_schema = schema["blocks"]

  # Default values for a new section of this kind.
  def default_settings
    settings = settings_schema.to_h { |setting| [ setting["id"], setting["default"] ] }.compact
    settings["blocks"] = Array(blocks_schema&.dig("default")) if blocks_schema
    settings
  end

  def parsed_liquid = @parsed_liquid ||= Email::Liquid.parse(liquid)

  private
    def liquid_parses
      Email::Liquid.parse(liquid)
    rescue Liquid::Error => error
      errors.add(:liquid, "has an error: #{error.message}")
    end

    def schema_is_valid
      bad = settings_schema.reject { |setting| setting["id"].present? && SETTING_TYPES.include?(setting["type"]) }
      errors.add(:schema, "has settings without an id or with an unknown type") if bad.any?
    end
end

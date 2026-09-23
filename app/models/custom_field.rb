# A church-defined attribute on people. Values live in people.custom_fields (jsonb),
# keyed by #key and stored in the type-appropriate JSON form produced by #cast.
class CustomField < ApplicationRecord
  include Positionable

  class InvalidValue < StandardError; end

  acts_as_tenant :church

  enum :field_type, { text: "text", number: "number", date: "date", boolean: "boolean",
    select: "select", multi_select: "multi_select" }, validate: true, instance_methods: false, scopes: false

  normalizes :options, with: ->(options) { options.map(&:strip).compact_blank.uniq }

  before_validation :derive_key, on: :create

  validates :label, presence: true
  validates :key, presence: true, format: { with: /\A[a-z][a-z0-9_]*\z/ }
  validates_uniqueness_to_tenant :key
  validates :options, presence: { message: "are required for select fields" }, if: :choice?
  validate :key_is_immutable, on: :update

  after_destroy :remove_values_from_people


  def choice?
    field_type.in?(%w[ select multi_select ])
  end

  # Returns the JSON value to store, nil for blank input, or raises InvalidValue.
  def cast(raw)
    return cast_multi_select(raw) if field_type == "multi_select"
    return if raw.nil? || raw.to_s.strip.empty?

    value = raw.to_s.strip
    case field_type
    when "text" then value
    when "number" then cast_number(value)
    when "date" then cast_date(value)
    when "boolean" then ActiveModel::Type::Boolean.new.cast(value)
    when "select" then value.in?(options) ? value : raise(InvalidValue, "must be one of: #{options.join(", ")}")
    end
  end

  def display(value)
    case field_type
    when "boolean" then value.nil? ? nil : (value ? "Yes" : "No")
    when "multi_select" then Array(value).join(", ")
    when "date" then value.present? ? I18n.l(Date.iso8601(value), format: :long) : nil
    else value
    end
  end

  private
    def cast_number(value)
      number = Float(value.delete(","))
      number == number.to_i ? number.to_i : number
    rescue ArgumentError
      raise InvalidValue, "must be a number"
    end

    def cast_date(value)
      Date.parse(value).iso8601
    rescue Date::Error
      raise InvalidValue, "must be a date"
    end

    def cast_multi_select(raw)
      values = (raw.is_a?(Array) ? raw : raw.to_s.split(/[;,]/)).map { |v| v.to_s.strip }.compact_blank
      unknown = values - options
      raise InvalidValue, "has unknown choices: #{unknown.join(", ")}" if unknown.any?

      values.presence
    end

    def derive_key
      self.key = label.to_s.parameterize(separator: "_").tr("-", "_").sub(/\A[^a-z]+/, "") if key.blank?
    end

    def key_is_immutable
      errors.add(:key, "can't be changed once people have values") if key_changed?
    end

    def remove_values_from_people
      Person.where("custom_fields ? :key", key:).update_all([ "custom_fields = custom_fields - ?", key ])
    end
end

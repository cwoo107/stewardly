# One question on a Form. Knows how to turn a raw submitted value into a stored
# answer (#cast_answer), how that value looks to show/hide rules (#rule_value),
# and where the answer goes on submission (#maps_to).
class FormField < ApplicationRecord
  include Positionable

  class InvalidAnswer < StandardError; end

  MAX_UPLOAD_SIZE = 10.megabytes
  UPLOAD_TYPES = %w[ image/png image/jpeg image/gif image/webp image/heic application/pdf ].freeze
  ADDRESS_PARTS = %w[ line1 line2 city region postal_code ].freeze
  TEXT_LIMITS = { "paragraph" => 5_000 }.freeze
  DEFAULT_TEXT_LIMIT = 255

  belongs_to :form, inverse_of: :fields
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  positioned within: :form_id

  enum :field_type, { text: "text", paragraph: "paragraph", email: "email", phone: "phone", number: "number", date: "date",
    select: "select", multi_select: "multi_select", checkbox: "checkbox", file: "file", address: "address" },
    validate: true, instance_methods: false, scopes: false

  normalizes :options, with: ->(options) { options.map(&:strip).compact_blank.uniq }
  normalizes :maps_to, with: ->(target) { target.presence }

  before_validation :derive_key, on: :create
  before_validation { self.sensitive = true if maps_to == "prayer_request.body" }

  validates :label, presence: true, length: { maximum: 200 }
  validates :key, presence: true, format: { with: /\A[a-z][a-z0-9_]*\z/ }, uniqueness: { scope: :form_id }
  validates :options, presence: { message: "are required for choice fields" }, if: :choice?
  validates :maps_to, uniqueness: { scope: :form_id, message: "is already used by another field" }, allow_nil: true
  validate :maps_to_suits_field
  validate :visibility_rule_is_valid
  validate :key_is_immutable, on: :update

  def choice? = field_type.in?(%w[ select multi_select ])

  def visibility_rule=(value)
    super(Form::Rule.normalize(value))
  end

  def rule
    Form::Rule.new(visibility_rule)
  end

  # Fields listed above this one, which its show/hide rule may refer to.
  def earlier_fields
    form.fields.select { |field| field.position < position && field.id != id }
  end

  # The value show/hide rules see: stripped strings, arrays for multi-select,
  # "true" for a ticked checkbox, "" when nothing was given. The browser builds
  # the same shape (form_logic_controller.js).
  def rule_value(raw)
    case field_type
    when "multi_select" then Array(raw).map(&:to_s).map(&:strip).compact_blank
    when "checkbox" then ActiveModel::Type::Boolean.new.cast(raw.presence) ? "true" : ""
    when "file" then raw.respond_to?(:original_filename) ? raw.original_filename : ""
    when "address" then address_parts(raw).values.any?(&:present?) ? "filled" : ""
    else raw.to_s.strip
    end
  end

  # Returns the answer to store (nil when blank) or raises InvalidAnswer.
  def cast_answer(raw)
    value = send("cast_#{field_type}", raw)
    blank = value.nil? || value == false || value == [] || value == {}
    raise InvalidAnswer, "is required" if required? && blank

    blank && field_type != "checkbox" ? nil : value
  end

  def display_answer(value)
    case field_type
    when "checkbox" then value ? "Yes" : "No"
    when "multi_select" then Array(value).join(", ")
    when "date" then value.present? ? I18n.l(Date.iso8601(value), format: :long) : nil
    when "address" then value.is_a?(Hash) ? value.values_at(*ADDRESS_PARTS).compact_blank.join(", ") : nil
    when "file" then value.is_a?(Hash) ? value["filename"] : nil
    else value
    end
  end

  private
    def cast_text(raw) = limited_text(raw)
    def cast_paragraph(raw) = limited_text(raw)

    def cast_email(raw)
      email = raw.to_s.strip.downcase.presence
      raise InvalidAnswer, "isn't a valid email address" if email && !email.match?(URI::MailTo::EMAIL_REGEXP)

      email
    end

    def cast_phone(raw)
      phone = raw.to_s.strip.presence
      raise InvalidAnswer, "isn't a valid phone number" if phone && !phone.gsub(/\D/, "").length.between?(7, 15)

      phone
    end

    def cast_number(raw)
      text = raw.to_s.strip.delete(",").presence or return
      number = Float(text)
      number == number.to_i ? number.to_i : number
    rescue ArgumentError
      raise InvalidAnswer, "must be a number"
    end

    def cast_date(raw)
      raw.to_s.strip.presence && Date.parse(raw.to_s).iso8601
    rescue Date::Error
      raise InvalidAnswer, "must be a date"
    end

    def cast_select(raw)
      value = raw.to_s.strip.presence or return
      raise InvalidAnswer, "must be one of the choices" unless options.include?(value)

      value
    end

    def cast_multi_select(raw)
      values = rule_value(raw)
      raise InvalidAnswer, "must be from the choices" if (values - options).any?

      values
    end

    def cast_checkbox(raw) = rule_value(raw) == "true"

    def cast_file(raw)
      return unless raw.respond_to?(:original_filename)
      raise InvalidAnswer, "must be an image or PDF" unless UPLOAD_TYPES.include?(Marcel::MimeType.for(raw, name: raw.original_filename))
      raise InvalidAnswer, "must be smaller than 10 MB" if raw.size > MAX_UPLOAD_SIZE

      raw
    end

    def cast_address(raw)
      parts = address_parts(raw)
      return {} if parts.values.all?(&:blank?)
      raise InvalidAnswer, "needs a street and a city or ZIP" if parts["line1"].blank? || (parts["city"].blank? && parts["postal_code"].blank?)

      parts.compact_blank
    end

    def address_parts(raw)
      hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
      ADDRESS_PARTS.to_h { |part| [ part, hash[part].to_s.strip.first(DEFAULT_TEXT_LIMIT) ] }
    rescue TypeError, ArgumentError
      ADDRESS_PARTS.to_h { |part| [ part, "" ] }
    end

    def limited_text(raw)
      text = raw.to_s.strip.presence or return
      limit = TEXT_LIMITS.fetch(field_type, DEFAULT_TEXT_LIMIT)
      raise InvalidAnswer, "is too long (#{limit} characters at most)" if text.length > limit

      text
    end

    def derive_key
      return if key.present?

      base = label.to_s.parameterize(separator: "_").tr("-", "_").sub(/\A[^a-z]+/, "").first(40).presence || "field"
      taken = form ? form.fields.map(&:key) : []
      candidate, suffix = base, 1
      candidate = "#{base}_#{suffix += 1}" while taken.include?(candidate)
      self.key = candidate
    end

    def key_is_immutable
      errors.add(:key, "can't change once created") if key_changed?
    end

    def maps_to_suits_field
      return if maps_to.nil?

      target = Form::Mapping.find(maps_to, form:)
      if target.nil?
        errors.add(:maps_to, "isn't a known destination")
      elsif target.field_types.exclude?(field_type)
        errors.add(:maps_to, "needs a #{target.field_types.map(&:humanize).map(&:downcase).to_sentence(last_word_connector: ", or ")} field")
      end
    end

    def visibility_rule_is_valid
      rule.errors(available_keys: form&.fields&.map(&:key).to_a - [ key ]).each { |message| errors.add(:visibility_rule, message) }
    end
end

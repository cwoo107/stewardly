# Validates a raw submission against a form, top to bottom:
# a field is visible when its rule holds for the (visible) answers above it; hidden
# fields are ignored even if a value was sent; visible ones are cast and validated.
#
#   response = Form::Response.new(form, params[:answers])
#   response.valid? # => false; response.errors # => { "email" => "isn't a valid email address" }
class Form::Response
  attr_reader :errors, :answers, :sensitive_answers, :uploads, :visible_keys

  def initialize(form, raw_answers)
    @form = form
    @raw = raw_answers.respond_to?(:to_unsafe_h) ? raw_answers.to_unsafe_h : raw_answers.to_h
    evaluate
  end

  def valid? = errors.empty?

  def value_for(key) = @raw[key]

  private
    def evaluate
      @errors, @answers, @sensitive_answers, @uploads, @visible_keys = {}, {}, {}, {}, []
      rule_values = {}

      @form.fields.each do |field|
        next unless field.rule.satisfied_by?(rule_values)

        raw = @raw[field.key]
        @visible_keys << field.key
        rule_values[field.key] = field.rule_value(raw)
        store(field, field.cast_answer(raw))
      rescue FormField::InvalidAnswer => error
        @errors[field.key] = error.message
      end
    end

    def store(field, value)
      return if value.nil?
      return @uploads[field.key] = value if field.field_type == "file"

      (field.sensitive? ? @sensitive_answers : @answers)[field.key] = value
    end
end

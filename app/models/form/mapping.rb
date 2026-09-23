# Where a form answer can go when a submission is processed.
class Form::Mapping
  Target = Data.define(:key, :label, :field_types)

  TEXTLIKE = %w[ text email phone select ].freeze

  PERSON = [
    Target.new("person.first_name", "Person: first name", %w[ text ]),
    Target.new("person.last_name", "Person: last name", %w[ text ]),
    Target.new("person.nickname", "Person: nickname", %w[ text ]),
    Target.new("person.email", "Person: email", %w[ email ]),
    Target.new("person.phone", "Person: phone", %w[ phone text ]),
    Target.new("person.birthdate", "Person: birthdate", %w[ date ]),
    Target.new("household.address", "Household: home address", %w[ address ])
  ].freeze

  PRAYER = [
    Target.new("prayer_request.body", "Prayer request: the request", %w[ paragraph text ]),
    Target.new("prayer_request.share_with_prayer_team", "Prayer request: OK to share with the prayer team", %w[ checkbox ])
  ].freeze

  # Custom fields accept the form field types whose answers cast cleanly into them.
  CUSTOM_FIELD_TYPES = {
    "text" => %w[ text paragraph select email phone ], "number" => %w[ number ], "date" => %w[ date ],
    "boolean" => %w[ checkbox ], "select" => %w[ select ], "multi_select" => %w[ multi_select ]
  }.freeze

  def self.targets(form:)
    custom = CustomField.ordered.map do |field|
      Target.new("person.custom.#{field.key}", "Person: #{field.label}", CUSTOM_FIELD_TYPES.fetch(field.field_type))
    end
    PERSON + custom + (form&.prayer_request_form? ? PRAYER : [])
  end

  def self.find(key, form:)
    targets(form:).find { |target| target.key == key }
  end

  # Destinations that suit a field type, for the builder's dropdown.
  def self.options_for(field)
    targets(form: field.form).select { |target| target.field_types.include?(field.field_type) }.map { |target| [ target.label, target.key ] }
  end
end

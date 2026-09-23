# The dates a "days before or after" trigger can count from.
module Workflow::DateFields
  def self.options
    { "Date added" => "created_at", "Birthday" => "birthdate" }
      .merge(CustomField.where(field_type: "date").order(:position).to_h { |field| [ field.label, "custom:#{field.key}" ] })
  end
end

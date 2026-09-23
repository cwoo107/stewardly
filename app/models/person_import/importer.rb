require "csv"

# Imports the rows of a PersonImport using its column mapping.
# - Matches existing (unmerged) people by email and updates the mapped, non-blank values.
# - Groups people into households by street address and postal code.
# - Works in batches, each in its own transaction, recording processed_count so a
#   retried job resumes after the last committed batch instead of starting over.
# - A bad row records its error and never stops the import.
class PersonImport::Importer
  BATCH_SIZE = 100

  PERSON_FIELDS = %w[ first_name last_name nickname email phone birthdate membership_status ].freeze
  HOUSEHOLD_FIELDS = %w[ address_line1 address_line2 city region postal_code ].freeze
  FIELD_LABELS = {
    "first_name" => "First name", "last_name" => "Last name", "nickname" => "Nickname", "email" => "Email",
    "phone" => "Phone", "birthdate" => "Birthdate", "membership_status" => "Membership status",
    "address_line1" => "Address line 1", "address_line2" => "Address line 2", "city" => "City",
    "region" => "State / region", "postal_code" => "Postal code", "tags" => "Tags (separated by ;)"
  }.freeze

  def self.field_options
    FIELD_LABELS.map { |key, label| [ label, key ] } + CustomField.ordered.map { |field| [ "Custom: #{field.label}", "custom:#{field.key}" ] }
  end

  def self.field_keys
    field_options.map(&:last)
  end

  def initialize(import)
    @import = import
    @custom_fields = CustomField.all.index_by(&:key)
    @tags = {}
  end

  def import!
    rows = CSV.parse(@import.file.download, headers: true, skip_blanks: true)
    @import.update!(status: :processing, row_count: rows.size, started_at: @import.started_at || Time.current)

    rows.each_slice(BATCH_SIZE).with_index do |batch, batch_index|
      first_index = batch_index * BATCH_SIZE
      next if first_index + batch.size <= @import.processed_count # committed on an earlier attempt

      import_batch(batch, first_index)
    end

    @import.update!(status: :completed, finished_at: Time.current)
  rescue CSV::MalformedCSVError => error
    @import.update!(status: :failed, finished_at: Time.current, row_errors: @import.row_errors + [ { "row" => nil, "message" => "The file isn't valid CSV: #{error.message}" } ])
  end

  private
    def import_batch(batch, first_index)
      counts = { created: 0, updated: 0 }
      errors = []

      PersonImport.transaction do
        batch.each_with_index do |row, offset|
          result = import_row(row)
          counts[result] += 1
        rescue ActiveRecord::RecordInvalid, CustomField::InvalidValue, Date::Error => error
          # CSV row 1 is the header, so data row n is spreadsheet row n + 2 (zero-based index)
          errors << { "row" => first_index + offset + 2, "message" => error.message }
        end

        @import.update!(
          processed_count: first_index + batch.size,
          created_count: @import.created_count + counts[:created],
          updated_count: @import.updated_count + counts[:updated],
          row_errors: @import.row_errors + errors)
      end
    end

    def import_row(row)
      values = mapped_values(row)

      Person.transaction(requires_new: true) do
        person = (values["email"].presence && Person.unmerged.find_by(email: values["email"].downcase)) || Person.new
        created = person.new_record?

        person.assign_attributes(values.slice(*PERSON_FIELDS).compact_blank)
        person.birthdate = Date.parse(values["birthdate"]) if values["birthdate"].present?
        person.membership_status = values["membership_status"].parameterize(separator: "_") if values["membership_status"].present?
        person.custom_field_values = custom_values(values)
        person.household ||= household_for(values)
        person.save!
        tag(person, values["tags"])

        created ? :created : :updated
      end
    end

    def mapped_values(row)
      @import.mapping.each_with_object({}) do |(header, field), values|
        values[field] = row[header]&.strip if field.present?
      end
    end

    def custom_values(values)
      values.filter_map do |field, value|
        key = field.delete_prefix("custom:")
        [ key, value ] if field.start_with?("custom:") && @custom_fields.key?(key)
      end.to_h
    end

    def household_for(values)
      address = values.slice(*HOUSEHOLD_FIELDS).compact_blank
      return if address["address_line1"].blank?

      Household.where("lower(address_line1) = ?", address["address_line1"].downcase)
        .find_by(postal_code: address["postal_code"]) ||
        Household.create!(address.merge("name" => "The #{values["last_name"]} household"))
    end

    def tag(person, names)
      names.to_s.split(";").map(&:squish).compact_blank.each do |name|
        tag = @tags[name.downcase] ||= Tag.where("lower(name) = ?", name.downcase).first || Tag.create!(name:)
        person.taggings.find_or_create_by!(tag:)
      end
    end
end

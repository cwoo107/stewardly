require "csv"

# Reads the header and first rows of an uploaded CSV so staff can check the
# column mapping before anything is imported.
class PersonImport::Preview
  SAMPLE_SIZE = 10

  # Header spellings we recognise, normalised to lowercase letters and digits only.
  SYNONYMS = {
    "first_name" => %w[ first firstname givenname forename ],
    "last_name" => %w[ last lastname surname familyname ],
    "nickname" => %w[ nickname preferredname goesby ],
    "email" => %w[ email emailaddress mail ],
    "phone" => %w[ phone phonenumber mobile cell cellphone ],
    "birthdate" => %w[ birthdate birthday dob dateofbirth ],
    "membership_status" => %w[ status membershipstatus membership ],
    "address_line1" => %w[ address address1 addressline1 street streetaddress ],
    "address_line2" => %w[ address2 addressline2 apartment unit ],
    "city" => %w[ city town ],
    "region" => %w[ state region province ],
    "postal_code" => %w[ zip zipcode postcode postalcode ],
    "tags" => %w[ tags tag labels ]
  }.freeze

  attr_reader :headers, :rows

  def initialize(import)
    csv = CSV.parse(import.file.download, headers: true, skip_blanks: true)
    @headers = csv.headers.compact
    @rows = csv.first(SAMPLE_SIZE).map(&:fields)
    @row_count = csv.size
  rescue CSV::MalformedCSVError => error
    @headers, @rows, @row_count, @error = [], [], 0, error.message
  end

  attr_reader :row_count, :error

  def suggested_mapping
    custom = CustomField.all.to_h { |field| [ normalize(field.label), "custom:#{field.key}" ] }

    headers.to_h do |header|
      normalized = normalize(header)
      field = SYNONYMS.find { |_, names| names.include?(normalized) }&.first || custom[normalized]
      [ header, field.to_s ]
    end
  end

  private
    def normalize(text) = text.to_s.downcase.gsub(/[^a-z0-9]/, "")
end

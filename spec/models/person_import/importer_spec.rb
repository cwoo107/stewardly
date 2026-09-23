require "rails_helper"

RSpec.describe PersonImport::Importer do
  let(:mapping) do
    { "First" => "first_name", "Last" => "last_name", "Email" => "email", "Street" => "address_line1", "Zip" => "postal_code",
      "Tags" => "tags", "Size" => "custom:size", "Born" => "birthdate", "Notes" => "" }
  end
  let(:csv) do
    <<~CSV
      First,Last,Email,Street,Zip,Tags,Size,Born,Notes
      Ada,Lovelace,ada@example.com,1 Analytical Way,37203,Newcomer; Volunteer,M,1990-12-10,ignored
      Charles,Lovelace,,1 analytical way,37203,Volunteer,,,
      ,Nameless,x@example.com,,,,,,
      Grace,Hopper,GRACE@example.com,,,,XXL,,
    CSV
  end
  let(:import) { create(:person_import, csv:).tap { |i| i.update!(mapping:) } }

  before { create(:custom_field, :select, key: "size", options: %w[ S M L ]) }

  it "imports rows, groups households, tags people, and records bad rows" do
    create(:person, first_name: "Old", last_name: "Hopper", email: "grace@example.com")

    described_class.new(import).import!

    expect(import.reload).to have_attributes(status: "completed", row_count: 4, processed_count: 4, created_count: 2, updated_count: 0)
    ada = Person.find_by!(email: "ada@example.com")
    charles = Person.find_by!(first_name: "Charles")
    expect(ada).to have_attributes(birthdate: Date.new(1990, 12, 10), custom_fields: { "size" => "M" })
    expect(ada.tags.pluck(:name)).to contain_exactly("Newcomer", "Volunteer")
    expect(charles.household).to eq(ada.household)
    expect(ada.household.name).to eq("The Lovelace household")

    expect(import.row_errors.map { |e| e["row"] }).to eq([ 4, 5 ])
    expect(import.row_errors.last["message"]).to include("must be one of")
    expect(Person.find_by!(email: "grace@example.com").first_name).to eq("Old") # bad row left untouched
  end

  it "updates people matched by email instead of duplicating them" do
    existing = create(:person, first_name: "A.", last_name: "Lovelace", email: "ada@example.com")
    import.update!(mapping: mapping.merge("Size" => "", "Tags" => ""))

    described_class.new(import).import!

    expect(existing.reload.first_name).to eq("Ada")
    expect(import.reload.updated_count).to eq(1)
  end

  it "resumes after the last committed batch when retried" do
    stub_const("#{described_class}::BATCH_SIZE", 2)
    import.update!(processed_count: 2, created_count: 1) # first batch committed on an earlier attempt

    described_class.new(import).import!

    expect(Person.where(first_name: %w[ Ada Charles ])).to be_empty
    expect(import.reload).to have_attributes(processed_count: 4, status: "completed")
  end

  it "marks the import failed for a file that isn't CSV" do
    bad = create(:person_import, csv: "a,\"b\nc")
    bad.update_columns(mapping: { "a" => "first_name", "b" => "last_name" })

    described_class.new(bad).import!

    expect(bad.reload.status).to eq("failed")
  end
end

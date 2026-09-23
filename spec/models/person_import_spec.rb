require "rails_helper"

RSpec.describe PersonImport do
  it_behaves_like "a tenant-scoped model"

  it "only accepts CSV files" do
    import = build(:person_import, file: Rack::Test::UploadedFile.new(StringIO.new("x"), "text/plain", original_filename: "people.txt"))
    expect(import).not_to be_valid
  end

  it "requires first and last name columns in the mapping" do
    import = create(:person_import)
    expect(import.update(mapping: { "Email" => "email" })).to be(false)
    expect(import.errors[:mapping].first).to include("first name and last name")
  end

  it "rejects unknown or repeated fields" do
    import = create(:person_import)
    expect(import.update(mapping: { "A" => "first_name", "B" => "last_name", "C" => "shoe_size" })).to be(false)
    expect(import.update(mapping: { "A" => "first_name", "B" => "last_name", "C" => "last_name" })).to be(false)
  end
end

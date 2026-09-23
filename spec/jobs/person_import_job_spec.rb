require "rails_helper"

RSpec.describe PersonImportJob do
  it "runs the importer" do
    import = create(:person_import)
    import.update!(mapping: { "First name" => "first_name", "Last name" => "last_name", "Email" => "email" })

    described_class.perform_now(import)

    expect(import.reload).to be_completed
    expect(Person.find_by!(email: "ada@example.com").last_name).to eq("Lovelace")
  end

  it "does nothing for a finished import (safe to retry)" do
    import = create(:person_import, status: "completed")
    expect(PersonImport::Importer).not_to receive(:new)
    described_class.perform_now(import)
  end
end

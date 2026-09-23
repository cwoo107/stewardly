require "rails_helper"

RSpec.describe PersonImport::Preview do
  it "shows headers and sample rows and guesses the mapping" do
    create(:custom_field, label: "T-shirt size")
    import = create(:person_import, csv: "First Name,Surname,E-mail,ZIP,T-shirt Size,Favorite color\nAda,Lovelace,ada@example.com,37203,M,Blue\n")

    preview = described_class.new(import)

    expect(preview.headers).to eq([ "First Name", "Surname", "E-mail", "ZIP", "T-shirt Size", "Favorite color" ])
    expect(preview.rows).to eq([ %w[ Ada Lovelace ada@example.com 37203 M Blue ] ])
    expect(preview.suggested_mapping).to eq(
      "First Name" => "first_name", "Surname" => "last_name", "E-mail" => "email", "ZIP" => "postal_code",
      "T-shirt Size" => "custom:t_shirt_size", "Favorite color" => "")
  end
end

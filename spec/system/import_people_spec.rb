require "rails_helper"

RSpec.describe "Importing people" do
  include ActiveJob::TestHelper

  it "uploads a CSV, maps columns, and imports" do
    file = Rails.root.join("tmp/import_people_spec.csv")
    File.write(file, "Given name,Family name,Email\nAda,Lovelace,ada@example.com\nAlan,Turing,alan@example.com\n")
    sign_in_as(create(:user, :staff))

    visit person_imports_path
    click_on "New import"
    attach_file "CSV file", file
    click_on "Upload and preview"

    expect(page).to have_content("Ada")
    select "First name", from: "Field for Given name"
    select "Last name", from: "Field for Family name"
    perform_enqueued_jobs(only: PersonImportJob) { click_on "Import 2 rows" }

    visit current_path
    expect(page).to have_content("Completed")
    expect(Person.pluck(:email)).to include("ada@example.com", "alan@example.com")
  ensure
    FileUtils.rm_f(file)
  end
end

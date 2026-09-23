require "rails_helper"

RSpec.describe "Importing people" do
  include ActiveJob::TestHelper

  let(:staff) { create(:user, :staff) }
  let(:csv) { Rack::Test::UploadedFile.new(StringIO.new("First,Last,E-mail\nAda,Lovelace,ada@example.com\n"), "text/csv", original_filename: "people.csv") }

  before { sign_in_as(staff) }

  it "uploads, previews with suggested mapping, and imports in a job" do
    post person_imports_path, params: { person_import: { file: csv } }
    import = PersonImport.last
    expect(response).to redirect_to(edit_person_import_path(import))

    get edit_person_import_path(import)
    expect(response.body).to include("Ada", "Lovelace")
    expect(response.body).to match(/<option selected="selected" value="first_name">/)

    expect {
      patch person_import_path(import), params: { person_import: { mapping: { "First" => "first_name", "Last" => "last_name", "E-mail" => "email" } } }
    }.to have_enqueued_job(PersonImportJob).with(import)
    expect(import.reload).to be_queued

    perform_enqueued_jobs(only: PersonImportJob)
    get person_import_path(import)
    expect(response.body).to include("Completed")
    expect(Person.find_by!(email: "ada@example.com").first_name).to eq("Ada")
  end

  it "rejects a mapping without names" do
    post person_imports_path, params: { person_import: { file: csv } }
    patch person_import_path(PersonImport.last), params: { person_import: { mapping: { "E-mail" => "email" } } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("must include a first name and last name")
  end

  it "rejects files that aren't CSV" do
    post person_imports_path, params: { person_import: { file: Rack::Test::UploadedFile.new(StringIO.new("x"), "application/pdf", original_filename: "people.pdf") } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "is forbidden to the care team" do
    sign_in_as(create(:user, :care_team))
    get new_person_import_path
    expect(response).to have_http_status(:forbidden)
  end
end

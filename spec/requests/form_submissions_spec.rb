require "rails_helper"

RSpec.describe "Form submissions" do
  let(:form) { create(:form, :connect_card, name: "Connect card") }
  let!(:submission) do
    form.fields.create!(key: "notes", label: "Private notes", field_type: "paragraph", sensitive: true)
    create(:form_submission, form:, answers: { "first_name" => "Ada", "last_name" => "Lovelace" }, sensitive_answers: { "notes" => "Secret" })
  end

  it "lists, shows, updates, and exports submissions for staff" do
    sign_in_as(create(:user, :staff))

    get form_submissions_path(form)
    expect(response.body).to include("Ada")

    get form_submission_path(form, submission)
    expect(response.body).to include("Lovelace", "Secret")

    patch form_submission_path(form, submission), params: { form_submission: { status: "reviewed" } }
    expect(submission.reload).to be_reviewed

    get form_submissions_path(form, format: :csv)
    expect(response.media_type).to eq("text/csv")
    expect(response.body).to include("Ada", "Secret")
  end

  it "hides sensitive answers from viewers who don't manage forms, including in exports" do
    sign_in_as(create(:user, roles: [ create(:role, permissions: %w[ view_form_submissions ]) ]))

    get form_submission_path(form, submission)
    expect(response.body).to include("Hidden: sensitive answer")
    expect(response.body).not_to include("Secret")

    get form_submissions_path(form, format: :csv)
    expect(response.body).not_to include("Secret")
    expect(response.body).not_to include("Private notes")
  end

  it "keeps prayer form submissions to pastoral staff, even from staff who build forms" do
    prayer_form = create(:form, :prayer)
    sign_in_as(create(:user, :staff))
    get form_submissions_path(prayer_form)
    expect(response).to have_http_status(:forbidden)
    get form_submissions_path(prayer_form, format: :csv)
    expect(response).to have_http_status(:forbidden)
  end

  it "is forbidden to members" do
    sign_in_as(create(:user, :member))
    get forms_path
    expect(response).to have_http_status(:forbidden)
  end
end

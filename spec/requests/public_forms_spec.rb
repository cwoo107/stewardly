require "rails_helper"

RSpec.describe "Public forms" do
  include ActiveJob::TestHelper

  let!(:form) { create(:form, :connect_card, name: "Connect card", confirmation_message: "Thanks for connecting!") }
  let(:answers) { { first_name: "Ada", last_name: "Lovelace", email: "ada@example.com", first_visit: "1", heard: "A friend" } }

  before { on_church(church) }

  # Submits as a person would: after loading the page and waiting a moment.
  def submit(answers, **extra)
    token = travel_to(5.seconds.ago) { PublicSubmissionProtection.started_at_token }
    post public_form_path(form.slug), params: { answers:, started_at: token }.merge(extra)
  end

  it "shows a published form without signing in" do
    get public_form_path(form.slug)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Connect card", "How did you hear about us?", 'data-controller="form-logic"')
    expect(response.body).not_to include("is required")
  end

  it "hides drafts and shows closed forms as closed" do
    draft = create(:form, name: "Secret draft")
    get public_form_path(draft.slug)
    expect(response).to have_http_status(:not_found)

    form.close!
    get public_form_path(form.slug)
    expect(response).to have_http_status(:gone)
    expect(response.body).to include("no longer accepting responses")
    submit(answers)
    expect(FormSubmission.count).to eq(0)
  end

  it "saves a valid submission, processes it, and thanks the submitter" do
    perform_enqueued_jobs(only: FormSubmissionJob) { submit(answers) }

    expect(response).to redirect_to(public_form_thanks_path(form.slug))
    submission = FormSubmission.sole
    expect(submission.answers).to include("first_name" => "Ada", "heard" => "A friend", "first_visit" => true)
    expect(submission.person.email).to eq("ada@example.com")
    expect(submission.ip_address).to eq("127.0.0.1")

    follow_redirect!
    expect(response.body).to include("Thanks for connecting!")
  end

  it "re-renders with errors from server-side validation" do
    submit(answers.merge(email: "not-an-email", last_name: ""))
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Email isn&#39;t a valid email address", "Last name is required")
    expect(FormSubmission.count).to eq(0)
  end

  it "drops answers to hidden questions" do
    submit(answers.merge(first_visit: "0"))
    expect(FormSubmission.sole.answers).not_to have_key("heard")
  end

  it "silently drops honeypot and too-fast submissions" do
    submit(answers, website: "http://spam.example")
    expect(response).to redirect_to(public_form_thanks_path(form.slug))

    post public_form_path(form.slug), params: { answers:, started_at: PublicSubmissionProtection.started_at_token }
    expect(response).to redirect_to(public_form_thanks_path(form.slug))

    post public_form_path(form.slug), params: { answers: } # no token at all
    expect(FormSubmission.count).to eq(0)
  end

  it "rate limits submissions per IP" do
    5.times { submit(answers) }
    submit(answers)
    expect(response).to have_http_status(:too_many_requests)
    expect(FormSubmission.count).to eq(5)
  end

  it "links a signed-in submitter to their own person" do
    user = create(:user, person: create(:person, first_name: "Old", last_name: "Name", email: "member@example.com"))
    sign_in_as(user)
    perform_enqueued_jobs(only: FormSubmissionJob) { submit(answers) }
    expect(FormSubmission.sole).to have_attributes(user:, person: user.person)
  end

  it "accepts uploads and keeps them with the submission" do
    form.fields.create!(key: "photo", label: "Photo", field_type: "file")
    image = Rack::Test::UploadedFile.new(StringIO.new("\x89PNG\r\n\x1a\n" + "0" * 20), "image/png", original_filename: "me.png")
    submit(answers.merge(photo: image))
    submission = FormSubmission.sole
    expect(submission.uploads.sole.filename.to_s).to eq("me.png")
    expect(submission.answers["photo"]).to include("filename" => "me.png")
  end

  it "can't be reached on another church's subdomain" do
    on_church(create(:church, subdomain: "elsewhere"))
    get public_form_path(form.slug)
    expect(response).to have_http_status(:not_found)
  end
end

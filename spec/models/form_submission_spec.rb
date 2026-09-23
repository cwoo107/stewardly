require "rails_helper"

RSpec.describe FormSubmission do
  it_behaves_like "a tenant-scoped model"

  it "encrypts sensitive answers and keeps the rest in jsonb" do
    submission = create(:form_submission, answers: { "name" => "Ruth" }, sensitive_answers: { "request" => "Chemo starts Monday" })
    raw = described_class.connection.select_rows("SELECT answers, sensitive_answers FROM form_submissions WHERE id = #{submission.id}").first

    expect(raw.first).to include("Ruth")
    expect(raw.last).not_to include("Chemo")
    expect(submission.reload.sensitive_answers).to eq("request" => "Chemo starts Monday")
  end

  it "is processed in a job after it's saved" do
    expect { create(:form_submission) }.to have_enqueued_job(FormSubmissionJob)
  end
end

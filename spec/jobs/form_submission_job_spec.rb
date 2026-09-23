require "rails_helper"

RSpec.describe FormSubmissionJob do
  it "processes the submission in its church" do
    form = create(:form, :connect_card)
    submission = create(:form_submission, form:, answers: { "first_name" => "Ada", "last_name" => "Lovelace" })
    ActsAsTenant.test_tenant = nil

    ActsAsTenant.with_tenant(church) { described_class.perform_now(submission) }

    expect(ActsAsTenant.with_tenant(church) { submission.reload.person&.full_name }).to eq("Ada Lovelace")
  end
end

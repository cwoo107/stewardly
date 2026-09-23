require "rails_helper"

RSpec.describe FormSubmission::Export do
  let(:form) { create(:form, :connect_card) }

  before do
    form.fields.create!(key: "notes", label: "Private notes", field_type: "paragraph", sensitive: true)
    form.fields.reset
    create(:form_submission, form:, answers: { "first_name" => "Ada", "first_visit" => true, "heard" => "Online" },
      sensitive_answers: { "notes" => "Secret" })
  end

  it "exports answers by label, leaving out sensitive answers unless allowed" do
    rows = CSV.parse(described_class.new(form, form.submissions, include_sensitive: false).to_csv)
    expect(rows.first).to eq([ "Submitted at", "Person", "Status", "First name", "Last name", "Email", "First visit", "How did you hear about us?" ])
    expect(rows.last.last(5)).to eq([ "Ada", nil, nil, "Yes", "Online" ])

    with_sensitive = described_class.new(form, form.submissions, include_sensitive: true).to_csv
    expect(with_sensitive).to include("Private notes", "Secret")
  end
end

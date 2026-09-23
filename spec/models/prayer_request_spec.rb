require "rails_helper"

RSpec.describe PrayerRequest do
  it_behaves_like "a tenant-scoped model"

  it "encrypts the request and answer at rest" do
    request = create(:prayer_request, body: "Surgery on Tuesday", answer_note: "Went well")
    raw = described_class.connection.select_rows("SELECT body, answer_note FROM prayer_requests WHERE id = #{request.id}").first
    expect(raw.join).not_to include("Surgery")
    expect(raw.join).not_to include("Went well")
    expect(request.reload.body).to eq("Surgery on Tuesday")
  end

  it "needs a person or a requester name" do
    expect(build(:prayer_request, person: nil, requester_name: nil)).not_to be_valid
    expect(build(:prayer_request, person: nil, requester_name: "A visitor")).to be_valid
  end

  it "stamps answered_at when answered" do
    request = create(:prayer_request)
    request.update!(status: "answered")
    expect(request.answered_at).to be_present
  end
end

require "rails_helper"

RSpec.describe Event do
  it_behaves_like "a tenant-scoped model"

  it "derives a unique slug" do
    expect(create(:event, title: "Fall Picnic!").slug).to eq("fall-picnic")
    expect(build(:event, title: "Other", slug: "fall-picnic")).not_to be_valid
  end

  it "only accepts event registration forms" do
    expect(build(:event, registration_form: create(:form))).not_to be_valid
    expect(build(:event, registration_form: create(:form, purpose: "event_registration"))).to be_valid
  end

  it "knows when registration is open" do
    event = build(:event, :registration, registration_opens_at: 1.day.from_now)
    expect(event.registration_open?).to be(false)
    travel 2.days do
      expect(event.registration_open?).to be(true)
    end
    expect(build(:event, :registration, status: "draft").registration_open?).to be(false)
    expect(build(:event).registration_open?).to be(false)
  end
end

require "rails_helper"

RSpec.describe Touchpoint do
  it_behaves_like "a tenant-scoped model"

  it "encrypts the body at rest" do
    touchpoint = create(:touchpoint, body: "Talked about a hard diagnosis")
    raw = described_class.connection.select_value("SELECT body FROM touchpoints WHERE id = #{touchpoint.id}")
    expect(raw).not_to include("diagnosis")
    expect(touchpoint.reload.body).to eq("Talked about a hard diagnosis")
  end

  it "defaults occurred_at to now" do
    freeze_time do
      expect(create(:touchpoint, occurred_at: nil).occurred_at).to eq(Time.current)
    end
  end

  it "can't point at another church's person" do
    foreign = ActsAsTenant.with_tenant(create(:church)) { create(:person) }
    expect(build(:touchpoint, person: nil, person_id: foreign.id)).not_to be_valid
  end
end

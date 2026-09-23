require "rails_helper"

RSpec.describe Team do
  it_behaves_like "a tenant-scoped model"

  it "can't belong to another church's ministry" do
    foreign = ActsAsTenant.with_tenant(create(:church)) { create(:ministry) }
    expect(build(:team, ministry: nil, ministry_id: foreign.id)).not_to be_valid
  end
end

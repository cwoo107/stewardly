require "rails_helper"

RSpec.describe Ministry do
  it_behaves_like "a tenant-scoped model"

  it "can't be deleted while it has teams" do
    team = create(:team)
    expect(team.ministry.destroy).to be(false)
  end
end

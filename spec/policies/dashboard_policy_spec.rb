require "rails_helper"

RSpec.describe DashboardPolicy do
  it "admits any signed-in user" do
    expect(described_class.new(create(:user, :member), :dashboard).show?).to be(true)
    expect(described_class.new(nil, :dashboard).show?).to be(false)
  end
end

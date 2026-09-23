require "rails_helper"

RSpec.describe TouchpointPolicy do
  it "hides sensitive notes from people without prayer access" do
    sensitive = build(:touchpoint, sensitive: true)
    expect(described_class.new(create(:user, :staff), sensitive).show_body?).to be(false)
    expect(described_class.new(create(:user, :care_team), sensitive).show_body?).to be(true)
    expect(described_class.new(create(:user, :staff), build(:touchpoint)).show_body?).to be(true)
  end
end

require "rails_helper"

RSpec.describe Blockout do
  it_behaves_like "a tenant-scoped model"

  it "defaults to one day and covers its range" do
    blockout = create(:blockout, starts_on: Date.new(2026, 10, 4), ends_on: nil)
    expect(blockout.ends_on).to eq(Date.new(2026, 10, 4))
    expect(Blockout.covering(Date.new(2026, 10, 4))).to include(blockout)
    expect(Blockout.covering(Date.new(2026, 10, 5))).to be_empty
  end

  it "can't end before it starts" do
    expect(build(:blockout, starts_on: Date.new(2026, 10, 4), ends_on: Date.new(2026, 10, 3))).not_to be_valid
  end
end

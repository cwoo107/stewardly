require "rails_helper"

RSpec.describe Pathway do
  it_behaves_like "a tenant-scoped model"

  it "installs Connect, Grow, Serve the first time it's needed, once" do
    pathway = described_class.current
    expect(described_class.current).to eq(pathway)
    expect(pathway.stages.map(&:name)).to eq(%w[ Connect Grow Serve ])
    expect(pathway.stages.map(&:stuck_after_days)).to eq([ 90, 180, nil ])
    expect(pathway.stages.second.conditions.map(&:type)).to eq(%w[ group course ])
  end
end

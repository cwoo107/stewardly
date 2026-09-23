require "rails_helper"

RSpec.describe Segment do
  it_behaves_like "a tenant-scoped model"

  it "normalizes form-style definitions" do
    segment = build(:segment, definition: { match: "any", conditions: { "0" => { type: "age", min: "18", junk: "x" } } })
    expect(segment.definition).to eq("match" => "any", "conditions" => [ { "type" => "age", "min" => "18" } ])
  end

  it "reports invalid conditions" do
    segment = build(:segment, definition: { conditions: [ { type: "age" }, { type: "bogus" } ] })
    expect(segment).not_to be_valid
    expect(segment.errors[:definition]).to include("condition 1: needs a minimum or maximum age", "condition 2: has an unknown type")
  end
end

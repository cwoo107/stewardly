require "rails_helper"

RSpec.describe PathwayStage do
  it_behaves_like "a tenant-scoped model"

  it "validates its rules and refuses rules about the pathway itself" do
    expect(build(:pathway_stage, definition: { conditions: [ { type: "age" } ] })).not_to be_valid
    stage = build(:pathway_stage, definition: { conditions: [ { type: "stuck", value: "yes" } ] })
    expect(stage).not_to be_valid
    expect(stage.errors[:definition].first).to include("can't depend on the pathway")
  end
end

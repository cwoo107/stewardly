require "rails_helper"

RSpec.describe Workflow::Definition do
  def step(id, type = "wait", yes: nil, no: nil)
    { "id" => id, "type" => type, "config" => {} }.merge(yes ? { "yes" => yes } : {}).merge(no ? { "no" => no } : {})
  end

  let(:definition) do
    described_class.new("steps" => [
      step("a"),
      step("if", "condition", yes: [ step("y1"), step("y2") ], no: []),
      step("b")
    ])
  end

  it "walks steps in order, into a branch, and back out after it" do
    expect(definition.first_step_id).to eq("a")
    expect(definition.next_step_id("a")).to eq("if")
    expect(definition.next_step_id("if", branch: "yes")).to eq("y1")
    expect(definition.next_step_id("y1")).to eq("y2")
    expect(definition.next_step_id("y2")).to eq("b")
    expect(definition.next_step_id("if", branch: "no")).to eq("b") # empty branch
    expect(definition.next_step_id("b")).to be_nil
  end

  it "edits steps in place, inside branches too" do
    definition.insert(step("n1"), parent_id: "if", branch: "no")
    definition.move("b", 0)
    definition.remove("y1")
    expect(definition.steps.map { |s| s["id"] }).to eq(%w[ b a if ])
    expect(definition.find("if")["no"].map { |s| s["id"] }).to eq(%w[ n1 ])
    expect(definition.find("if")["yes"].map { |s| s["id"] }).to eq(%w[ y2 ])
    expect { definition.insert(step("x"), parent_id: "a", branch: "yes") }.to raise_error(ArgumentError)
  end

  it "explains what stops it being published" do
    errors = described_class.new("trigger" => { "type" => "tag_added" }, "steps" => [ Workflow::Steps.build("send_email") ]).errors
    expect(errors).to include("Trigger needs a tag", a_string_including("Step 1 (Send an email): choose a template"))
  end
end

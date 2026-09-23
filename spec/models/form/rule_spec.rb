require "rails_helper"

RSpec.describe Form::Rule do
  # The same cases run through form_logic_controller.js in spec/system/form_rules_parity_spec.rb.
  JSON.parse(Rails.root.join("spec/fixtures/files/form_rules.json").read).each do |example|
    it example["name"] do
      expect(described_class.new(example["rule"]).satisfied_by?(example["answers"])).to be(example["expected"])
    end
  end

  it "normalizes form params, dropping blank and removed conditions" do
    rule = described_class.normalize("match" => "any", "conditions" => {
      "0" => { "field" => "a", "operator" => "filled", "value" => "ignored" },
      "1" => { "field" => "", "operator" => "equals" },
      "2" => { "field" => "b", "operator" => "equals", "value" => " x ", "_destroy" => "1" }
    })
    expect(rule).to eq("match" => "any", "conditions" => [ { "field" => "a", "operator" => "filled", "value" => "" } ])
    expect(described_class.normalize({})).to eq({})
  end

  it "describes itself" do
    rule = described_class.new("match" => "all", "conditions" => [ { "field" => "visit", "operator" => "filled" }, { "field" => "age", "operator" => "greater_than", "value" => "17" } ])
    expect(rule.summary("visit" => "First visit", "age" => "Age")).to eq("Shown when First visit is filled in and Age is more than “17”")
  end
end

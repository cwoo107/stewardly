require "rails_helper"

# Runs spec/fixtures/files/form_rules.json through the browser's evaluator, so the
# JavaScript show/hide logic can never drift from Form::Rule (see spec/models/form/rule_spec.rb).
RSpec.describe "Form rules in the browser", :js do
  it "evaluates every shared case exactly like Form::Rule" do
    cases = JSON.parse(Rails.root.join("spec/fixtures/files/form_rules.json").read)
    visit_church(church)
    visit new_session_path

    results = page.evaluate_async_script(<<~JS, cases)
      const [cases, done] = arguments
      import("controllers/form_logic_controller").then(({ evaluateRule }) => done(cases.map(c => evaluateRule(c.rule, c.answers))))
    JS

    mismatches = cases.zip(results).reject { |example, result| result == example["expected"] }.map { |example, _| example["name"] }
    expect(mismatches).to be_empty
    expect(cases.map { |example| Form::Rule.new(example["rule"]).satisfied_by?(example["answers"]) }).to eq(results)
  end
end

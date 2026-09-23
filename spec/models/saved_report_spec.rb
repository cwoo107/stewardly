require "rails_helper"

RSpec.describe SavedReport do
  it "re-runs its tool calls for fresh numbers" do
    user = create(:user, :church_admin)
    report = create(:saved_report, user:)
    report.rerun!
    before = report.results.first.dig("result", "figures", "People")
    create(:person)
    report.rerun!
    expect(report.reload.results.first.dig("result", "figures", "People")).to eq(before + 1)
  end
end

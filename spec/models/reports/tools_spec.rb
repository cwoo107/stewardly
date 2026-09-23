require "rails_helper"

RSpec.describe Reports::Tools do
  let(:admin) { create(:user, :church_admin) }

  def run(name, arguments = {}, user: admin) = Reports::Execution.run(name, arguments, user:, church:)

  it "measures group connection for people who joined, including unconnected people near a group" do
    group = create(:group, active: true, location: "POINT(-89.65 39.78)")
    near = create(:household, location: "POINT(-89.66 39.79)")
    far = create(:household, location: "POINT(-88.0 41.0)")
    create(:person).then { |p| create(:group_membership, person: p, group:) }
    create(:person, household: near)
    create(:person, household: far)
    create(:person, created_at: 2.years.ago)

    figures = run("group_connection", { "joined_from" => church.today.beginning_of_year.iso8601, "miles" => 3 })["result"]["figures"]
    joined = figures["People who joined"]
    expect(figures).to include("In a group" => 1, "Not in a group" => joined - 1, "Not in a group, within 3 miles of an active group" => 1)
    expect(figures["Connected (%)"]).to eq((100.0 / joined).round(1))
  end

  it "counts people and ignores unknown arguments" do
    create_list(:person, 2, membership_status: "member")
    result = run("people_counts", { "by" => "membership_status", "drop_table" => "people" })["result"]
    expect(result["tables"].first["rows"]).to include([ "Member", be >= 2 ])
  end

  it "checks each tool's permission, and only offers private totals when a church admin allows them" do
    staff = create(:user, :staff)
    expect(run("giving_summary", user: staff)["error"]).to include("No tool")
    expect(described_class.available(admin, church).map(&:tool_name)).not_to include("private_area_totals")

    church.update!(ai_private_totals: true)
    create(:benevolence_case, summary: "Secret")
    result = run("private_area_totals", user: admin)["result"]
    expect(result["figures"]).to include("Benevolence requests" => 1)
    expect(result.to_json).not_to include("Secret")
  end
end

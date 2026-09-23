require "rails_helper"

RSpec.describe PrayerRequestPolicy do
  let(:pastor) { create(:user, :church_admin) }
  let(:prayer_team) { create(:user, :care_team) }
  let!(:team_request) { create(:prayer_request, visibility: "prayer_team") }
  let!(:pastoral_request) { create(:prayer_request, visibility: "pastoral_staff") }

  it "shows pastors everything" do
    expect(described_class::Scope.new(pastor, PrayerRequest).resolve).to contain_exactly(team_request, pastoral_request)
    expect(described_class.new(pastor, pastoral_request).update?).to be(true)
  end

  it "shows the prayer team only prayer-team requests and ones assigned to them" do
    expect(described_class::Scope.new(prayer_team, PrayerRequest).resolve).to contain_exactly(team_request)
    expect(described_class.new(prayer_team, pastoral_request).show?).to be(false)

    create(:prayer_assignment, prayer_request: pastoral_request, user: prayer_team)
    expect(described_class::Scope.new(prayer_team, PrayerRequest).resolve).to contain_exactly(team_request, pastoral_request)
    expect(described_class.new(prayer_team, pastoral_request.reload).show?).to be(true)
    expect(described_class.new(prayer_team, team_request).update?).to be(false)
  end

  it "keeps staff without prayer permissions out" do
    staff = create(:user, :staff)
    expect(described_class.new(staff, PrayerRequest).index?).to be(false)
    expect(described_class::Scope.new(staff, PrayerRequest).resolve).to be_empty
  end
end

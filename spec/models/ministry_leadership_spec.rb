require "rails_helper"

RSpec.describe MinistryLeadership do
  it_behaves_like "a tenant-scoped model"

  it "audits leaders being added and removed" do
    leadership = create(:ministry_leadership)
    expect(AuditEvent.last).to have_attributes(action: "ministry_leader.added", auditable: leadership.user)

    leadership.destroy!
    expect(AuditEvent.last.action).to eq("ministry_leader.removed")
  end

  it "makes the user a leader of that ministry only" do
    leadership = create(:ministry_leadership)
    other = create(:ministry)
    user = User.find(leadership.user_id)
    expect(user.leads?(leadership.ministry)).to be(true)
    expect(user.leads?(other)).to be(false)
  end
end

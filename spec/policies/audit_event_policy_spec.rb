require "rails_helper"

RSpec.describe AuditEventPolicy do
  it "requires view_audit_log" do
    expect(described_class.new(create(:user, :church_admin), AuditEvent).index?).to be(true)
    expect(described_class.new(create(:user, :care_team), AuditEvent).index?).to be(false)
  end

  it "scopes to nothing without view_audit_log" do
    create(:audit_event)
    expect(described_class::Scope.new(create(:user, :staff), AuditEvent).resolve).to be_empty
  end
end

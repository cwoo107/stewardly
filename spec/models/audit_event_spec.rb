require "rails_helper"

RSpec.describe AuditEvent do
  it_behaves_like "a tenant-scoped model"

  describe ".record!" do
    it "takes the actor and IP address from Current" do
      actor = create(:user)
      Current.session = build(:session, user: actor)
      Current.ip_address = "203.0.113.9"

      event = described_class.record!(action: "user.deleted", auditable: church, metadata: { reason: "test" })

      expect(event).to have_attributes(actor:, ip_address: "203.0.113.9", auditable: church, metadata: { "reason" => "test" })
    end

    it "records system actions without an actor" do
      expect(described_class.record!(action: "user.deleted", auditable: church).actor).to be_nil
    end
  end

  it "is append-only" do
    event = create(:audit_event)
    expect { event.update!(action: "changed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { event.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "describes role changes in words" do
    event = build(:audit_event, action: "role.granted", metadata: { "role_name" => "Staff", "user_name" => "Ann Lee" })
    expect(event.description).to eq("granted Staff to Ann Lee")
  end
end

require "rails_helper"

RSpec.describe Church::Provisioning do
  subject(:provisioning) do
    described_class.new(name: "Grace Community Church", subdomain: "grace", time_zone: "Central Time (US & Canada)",
      admin: { first_name: "Dana", last_name: "Whitfield", email_address: "dana@grace.test", password: "password" })
  end

  before { ActsAsTenant.test_tenant = nil }

  it "creates the church with default roles and a church admin" do
    church = provisioning.provision!

    ActsAsTenant.with_tenant(church) do
      expect(Role.pluck(:key)).to match_array(Role::DEFAULTS.pluck(:key))
      expect(Role.all).to all(be_system)
      expect(Campus.sole).to have_attributes(name: "Main campus", is_default: true)
      expect(Form.pluck(:slug)).to contain_exactly("connect", "prayer", "help")

      admin = User.sole
      expect(admin.email_address).to eq("dana@grace.test")
      expect(admin.person).to have_attributes(first_name: "Dana", last_name: "Whitfield", membership_status: "member")
      expect(admin).to be_church_admin
      expect(admin.authenticate("password")).to be_truthy
    end
  end

  it "creates nothing when any part is invalid" do
    invalid = described_class.new(name: "Grace", subdomain: "grace", time_zone: "Central Time (US & Canada)",
      admin: { first_name: "Dana", last_name: "Whitfield", email_address: "not-an-email", password: "password" })

    expect { invalid.provision! }.to raise_error(ActiveRecord::RecordInvalid)
    expect(Church.exists?(subdomain: "grace")).to be(false)
    expect(ActsAsTenant.without_tenant { [ Role.count, User.count, Person.count ] }).to eq([ 0, 0, 0 ])
  end
end

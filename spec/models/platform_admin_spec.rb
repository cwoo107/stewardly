require "rails_helper"

RSpec.describe PlatformAdmin do
  it "is not tenant-scoped" do
    ActsAsTenant.test_tenant = nil
    expect { described_class.count }.not_to raise_error
  end

  it "requires a unique email address" do
    create(:platform_admin, email_address: "ops@stewardly.test")
    expect(build(:platform_admin, email_address: "OPS@stewardly.test")).not_to be_valid
  end
end

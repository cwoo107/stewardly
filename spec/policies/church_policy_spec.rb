require "rails_helper"

RSpec.describe ChurchPolicy do
  it "lets church admins edit their own church's settings" do
    expect(described_class.new(create(:user, :church_admin), church).update?).to be(true)
  end

  it "denies everyone else" do
    %i[ staff care_team member ].each do |role|
      expect(described_class.new(create(:user, role), church).update?).to be(false), "expected #{role} to be denied"
    end
  end

  it "denies admins access to another church" do
    other = create(:church)
    expect(described_class.new(create(:user, :church_admin), other).update?).to be(false)
  end
end

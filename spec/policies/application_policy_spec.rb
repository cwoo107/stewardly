require "rails_helper"

RSpec.describe ApplicationPolicy do
  it "denies every action by default" do
    policy = described_class.new(create(:user, :church_admin), Object.new)
    expect(%i[ index? show? create? new? update? edit? destroy? ].map { |action| policy.public_send(action) }).to all(be(false))
  end

  it "scopes to nothing by default" do
    create(:person)
    expect(described_class::Scope.new(create(:user, :church_admin), Person).resolve).to be_empty
  end
end

require "rails_helper"

RSpec.describe Tag do
  it_behaves_like "a tenant-scoped model"

  it "keeps names unique per church, ignoring case" do
    create(:tag, name: "Volunteer")
    expect(build(:tag, name: "volunteer")).not_to be_valid
  end

  it "only allows palette colors" do
    expect(build(:tag, color: "chartreuse")).not_to be_valid
  end
end

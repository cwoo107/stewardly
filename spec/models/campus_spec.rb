require "rails_helper"

RSpec.describe Campus do
  it_behaves_like "a tenant-scoped model"

  it "allows one default campus per church" do
    create(:campus, is_default: true)
    expect(build(:campus, is_default: true)).not_to be_valid
  end

  it "won't delete the default campus" do
    campus = create(:campus, is_default: true)
    expect(campus.destroy).to be(false)
  end
end

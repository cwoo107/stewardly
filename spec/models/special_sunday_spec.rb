require "rails_helper"

RSpec.describe SpecialSunday do
  it_behaves_like "a tenant-scoped model"

  it "keys days by name so each year's is the same kind" do
    expect(create(:special_sunday, name: "Back to  School").key).to eq("back-to-school")
  end

  it "is one per date" do
    day = create(:special_sunday)
    expect(build(:special_sunday, local_date: day.local_date)).not_to be_valid
  end
end

require "rails_helper"

RSpec.describe DuplicateDismissal do
  it_behaves_like "a tenant-scoped model"

  it "stores each pair once regardless of order" do
    a, b = create_list(:person, 2)
    create(:duplicate_dismissal, person: b, other_person: a)
    expect(build(:duplicate_dismissal, person: a, other_person: b)).not_to be_valid
    expect(DuplicateDismissal.sole).to have_attributes(person_id: [ a.id, b.id ].min)
  end
end

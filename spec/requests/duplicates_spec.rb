require "rails_helper"

RSpec.describe "Duplicates and merging" do
  let(:staff) { create(:user, :staff) }
  let!(:sam) { create(:person, first_name: "Sam", last_name: "Lee", email: "sam@example.com") }
  let!(:samuel) { create(:person, first_name: "Samuel", last_name: "Lee", email: "sam@example.com", phone: "555-0100") }

  before { sign_in_as(staff) }

  it "lists likely duplicates and merges one into the other" do
    get duplicates_path
    expect(response.body).to include("Sam Lee", "Samuel Lee", "Same email")

    get new_person_merge_path(sam, duplicate_id: samuel.id)
    expect(response).to have_http_status(:ok)

    post person_merge_path(sam), params: { duplicate_id: samuel.id }
    expect(response).to redirect_to(person_path(sam))
    expect(sam.reload.phone).to eq("555-0100")
    expect(samuel.reload).to be_merged
  end

  it "shows why a merge can't happen" do
    create(:user, person: sam)
    create(:user, person: samuel, email_address: "samuel@example.com")

    post person_merge_path(sam), params: { duplicate_id: samuel.id }

    follow_redirect!
    expect(response.body).to include("Both people have login accounts")
  end

  it "dismisses a pair so it stops being suggested" do
    post duplicate_dismissals_path, params: { duplicate_dismissal: { person_id: samuel.id, other_person_id: sam.id } }
    get duplicates_path
    expect(response.body).not_to include("Samuel Lee")
  end

  it "is forbidden without manage_people" do
    sign_in_as(create(:user, :care_team))
    post person_merge_path(sam), params: { duplicate_id: samuel.id }
    expect(response).to have_http_status(:forbidden)
    expect(samuel.reload).not_to be_merged
  end
end

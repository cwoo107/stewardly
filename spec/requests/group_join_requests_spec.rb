require "rails_helper"

RSpec.describe "Group join requests" do
  include ActiveJob::TestHelper

  let(:group) { create(:group) }
  let!(:join_request) { create(:group_join_request, group:, message: "We're new!") }

  it "lets a group leader who can sign in approve" do
    leader = create(:user, :member)
    create(:group_membership, group:, person: leader.person, role: "leader")
    sign_in_as(leader)

    get group_path(group)
    expect(response.body).to include("We&#39;re new!")
    patch group_join_request_path(group, join_request), params: { decision: "approve" }
    expect(group.people).to include(join_request.person)
  end

  it "lets staff decline" do
    sign_in_as(create(:user, :staff))
    expect { patch group_join_request_path(group, join_request), params: { decision: "decline" } }.to have_enqueued_mail(GroupJoinRequestMailer, :decided)
    expect(join_request.reload).to be_declined
  end

  it "keeps other members from deciding" do
    sign_in_as(create(:user, :member))
    patch group_join_request_path(group, join_request), params: { decision: "approve" }
    expect(response).to have_http_status(:forbidden)
  end
end

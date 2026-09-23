require "rails_helper"

RSpec.describe GroupJoinRequest do
  include ActiveJob::TestHelper

  it_behaves_like "a tenant-scoped model"

  let(:leader) { create(:user) }

  it "tells the leaders, and approving adds the person to the group" do
    group = create(:group)
    expect { create(:group_join_request, group:) }.to have_enqueued_mail(GroupJoinRequestMailer, :received)

    join_request = GroupJoinRequest.last
    expect { join_request.approve!(by: leader) }.to have_enqueued_mail(GroupJoinRequestMailer, :decided)
    expect(group.people).to include(join_request.person)
    expect(join_request).to have_attributes(status: "approved", decided_by: leader)
  end

  it "can't be made by someone already in the group" do
    membership = create(:group_membership)
    expect(build(:group_join_request, group: membership.group, person: membership.person)).not_to be_valid
  end

  it "fails to approve into a full group" do
    group = create(:group, capacity: 1)
    create(:group_membership, group:)
    join_request = create(:group_join_request, group: group.reload)
    expect { join_request.approve!(by: leader) }.to raise_error(ActiveRecord::RecordInvalid, /is full/)
    expect(join_request.reload).to be_pending
  end
end

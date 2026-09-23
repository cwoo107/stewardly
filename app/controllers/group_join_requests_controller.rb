class GroupJoinRequestsController < ApplicationController
  def update
    group = Group.find(params.expect(:group_id))
    join_request = authorize group.join_requests.pending.find(params.expect(:id))
    params.expect(:decision) == "approve" ? join_request.approve!(by: Current.user) : join_request.decline!(by: Current.user)
    redirect_to group, notice: "#{join_request.person.name}'s request was #{join_request.status}.", status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    redirect_to group, alert: error.record.errors.full_messages.to_sentence, status: :see_other
  end
end

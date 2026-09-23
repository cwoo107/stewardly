class Member::JoinRequestsController < Member::BaseController
  def create
    group = Group.active.find(params.expect(:group_id))
    join_request = person.group_join_requests.new(group:, message: params.dig(:group_join_request, :message))
    authorize join_request, :create_own?
    if join_request.save
      redirect_to member_group_path(group), notice: "Request sent. A leader will be in touch.", status: :see_other
    else
      redirect_to member_group_path(group), alert: join_request.errors.full_messages.to_sentence, status: :see_other
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to member_group_path(group), notice: "You've already asked to join.", status: :see_other
  end
end

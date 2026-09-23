class Member::GroupsController < Member::BaseController
  def index
    @memberships = person.group_memberships.includes(:group)
    @pending_group_ids = person.group_join_requests.pending.pluck(:group_id)
    @nearest = person.household&.nearest_groups(limit: 6)&.to_a.to_a
    @nearest = Group.active.alphabetical.limit(6).to_a if @nearest.empty?
    @nearest.reject! { |group| @memberships.any? { |m| m.group_id == group.id } }
  end

  def show
    @group = Group.active.find(params.expect(:id))
    @member = person.group_memberships.exists?(group: @group)
    @pending = person.group_join_requests.pending.exists?(group: @group)
  end
end

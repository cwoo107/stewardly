class GroupMembershipsController < ApplicationController
  before_action :set_group

  def create
    membership = authorize @group.group_memberships.new(person: Person.unmerged.find(params.expect(group_membership: [ :person_id ])[:person_id]))
    if membership.save
      redirect_to @group, notice: "#{membership.person.name} joined #{@group.name}.", status: :see_other
    else
      redirect_to @group, alert: membership.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def update
    membership = authorize @group.group_memberships.find(params.expect(:id))
    membership.update!(params.expect(group_membership: [ :role ]))
    redirect_to @group, notice: "#{membership.person.name} is now a #{membership.role}.", status: :see_other
  end

  def destroy
    membership = authorize @group.group_memberships.find(params.expect(:id))
    membership.destroy!
    redirect_to @group, notice: "#{membership.person.name} left #{@group.name}.", status: :see_other
  end

  private
    def set_group
      @group = Group.find(params.expect(:group_id))
    end
end

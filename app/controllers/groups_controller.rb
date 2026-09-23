class GroupsController < ApplicationController
  before_action :set_group, only: %i[ show edit update destroy ]

  def index
    authorize Group
    groups = policy_scope(Group).alphabetical.includes(:ministry, :group_memberships)
    groups = groups.where(group_type: params[:group_type]) if Group.group_types.key?(params[:group_type])
    groups = groups.where(ministry_id: params[:ministry_id]) if params[:ministry_id].present?
    groups = groups.active unless params[:inactive] == "1"
    @groups = groups
  end

  def show
    @memberships = @group.group_memberships.includes(:person).sort_by { |m| [ m.leader? ? 0 : 1, m.person.last_name, m.person.first_name ] }
  end

  def new
    @group = authorize Group.new(ministry_id: params[:ministry_id])
  end

  def create
    @group = authorize Group.new(group_params)
    if @group.save
      redirect_to @group, notice: "Group added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    @group.assign_attributes(group_params)
    authorize @group # the ministry may have changed; the user must be able to manage the new one too
    if @group.save
      redirect_to @group, notice: "Saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @group.destroy!
    redirect_to groups_path, notice: "Group deleted.", status: :see_other
  end

  private
    def set_group
      @group = authorize policy_scope(Group).find(params.expect(:id))
    end

    def group_params
      params.expect(group: %i[ name description ministry_id group_type capacity meeting_day meeting_time meeting_frequency active
        address_line1 address_line2 city region postal_code country ])
    end
end

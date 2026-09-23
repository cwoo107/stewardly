class MinistriesController < ApplicationController
  before_action :set_ministry, only: %i[ show edit update destroy ]

  def index
    authorize Ministry
    @ministries = policy_scope(Ministry).alphabetical.includes(:groups, :teams, leaders: :person)
  end

  def show
    @groups = @ministry.groups.alphabetical.includes(:group_memberships)
    @teams = @ministry.teams.alphabetical.includes(:positions, :team_memberships)
    @leadership_candidates = User.alphabetical.includes(:person).where.not(id: @ministry.leader_ids) if policy(@ministry).manage_leaders?
  end

  def new
    @ministry = authorize Ministry.new
  end

  def create
    @ministry = authorize Ministry.new(ministry_params)
    if @ministry.save
      redirect_to @ministry, notice: "Ministry added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @ministry.update(ministry_params)
      redirect_to @ministry, notice: "Saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @ministry.destroy
      redirect_to ministries_path, notice: "Ministry deleted.", status: :see_other
    else
      redirect_to @ministry, alert: @ministry.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private
    def set_ministry
      @ministry = authorize policy_scope(Ministry).includes(leaders: :person).find(params.expect(:id))
    end

    def ministry_params
      params.expect(ministry: %i[ name description ])
    end
end

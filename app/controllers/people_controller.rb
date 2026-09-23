class PeopleController < ApplicationController
  before_action :set_person, only: %i[ show edit update destroy ]

  def index
    authorize Person
    @segment = policy_scope(Segment).find_by(id: params[:segment_id]) if params[:segment_id].present?
    people = policy_scope(Person)
    people = people.merge(@segment.people) if @segment
    people = people.joins(:taggings).where(taggings: { tag_id: params[:tag_id] }) if params[:tag_id].present?
    people = people.where(membership_status: params[:status]) if Person.membership_statuses.key?(params[:status])
    @pagy, @people = pagy(people.search(params[:q]).alphabetical.includes(:tags, :household))
  end

  def search
    authorize Person
    @target = membership_target
    @people = params[:q].to_s.strip.length >= 2 ? Person.unmerged.search(params[:q]).alphabetical.limit(10) : Person.none
  end

  def show
    @touchpoints = @person.touchpoints.recent_first.includes(author: :person).limit(50)
    @prayer_requests = policy_scope(PrayerRequest).where(person: @person).recent_first if policy(PrayerRequest).index?
    @giving = Giving::PersonSummary.new(@person) if policy(Donation).index?
    @benevolence_cases = policy_scope(BenevolenceCase).where(person: @person).recent_first if policy(BenevolenceCase).index?
    @workflow_runs = @person.workflow_runs.includes(:workflow, :workflow_version).recent_first.limit(10) if policy(WorkflowRun).index?
  end

  def new
    @person = authorize Person.new(household_id: params[:household_id])
  end

  def create
    @person = authorize Person.new(person_params)
    if @person.save
      redirect_to @person, notice: "#{@person.name} was added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @person.update(person_params)
      redirect_to @person, notice: "Saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @person.destroy
      redirect_to people_path, notice: "#{@person.name} was deleted.", status: :see_other
    else
      redirect_to @person, alert: @person.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private
    def set_person
      @person = authorize policy_scope(Person).includes(:household, :tags, groups: :ministry, teams: :ministry, pathway_placement: :pathway_stage).find(params.expect(:id))
    end

    def person_params
      params.expect(person: [ :first_name, :last_name, :nickname, :email, :phone, :birthdate, :membership_status,
        :household_id, :household_role, tag_ids: [], custom_field_values: {} ])
    end

    # Search results offer an "Add" button for the group or team being edited.
    def membership_target
      case params[:for]
      when /\Agroup:(\d+)\z/ then policy_scope(Group).find($1)
      when /\Ateam:(\d+)\z/ then Team.find($1)
      when "benevolence" then :benevolence if policy(BenevolenceCase).create?
      when /\Adonation:(\d+)\z/ then policy_scope(Donation).find($1)
      end
    end
end

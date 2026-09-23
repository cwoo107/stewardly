# Members add and update the people in their own household (e.g. children).
class Member::HouseholdMembersController < Member::BaseController
  before_action :require_household
  before_action :set_member, only: %i[ edit update ]

  def new
    @member = @household.people.new(last_name: person.last_name, household_role: "child")
  end

  def create
    @member = @household.people.new(member_params)
    if @member.save
      redirect_to member_profile_path, notice: "#{@member.first_name} was added to your household."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @member.update(member_params)
      redirect_to member_profile_path, notice: "Saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def require_household
      @household = person.household or redirect_to(edit_member_profile_path, alert: "Add your home address first.")
    end

    def set_member
      @member = @household.people.where.not(id: person.id).find(params.expect(:id))
    end

    def member_params
      params.expect(person: %i[ first_name last_name nickname birthdate household_role ])
    end
end

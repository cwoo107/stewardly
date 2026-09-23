# A member's own details and household address. Their sign-in email is managed by staff.
class Member::ProfilesController < Member::BaseController
  def show
    @household = person.household
  end

  def edit
    @household = person.household || person.build_household(name: "The #{person.last_name} household")
  end

  def update
    @household = person.household || person.build_household(name: "The #{person.last_name} household")
    person.assign_attributes(params.expect(person: %i[ first_name last_name nickname phone birthdate ]))
    @household.assign_attributes(params.fetch(:household, {}).permit(:address_line1, :address_line2, :city, :region, :postal_code))

    if Person.transaction { @household.save! && person.save! }
      redirect_to member_profile_path, notice: "Saved."
    else
      render :edit, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_content
  end
end

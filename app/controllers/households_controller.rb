class HouseholdsController < ApplicationController
  before_action :set_household, only: %i[ show edit update destroy ]

  def index
    authorize Household
    @pagy, @households = pagy(policy_scope(Household).search(params[:q]).alphabetical.includes(:people))
  end

  def show
    @nearest_groups = @household.nearest_groups
    @display_location = @household.display_location_for(Current.user)
  end

  def new
    @household = authorize Household.new
  end

  def create
    @household = authorize Household.new(household_params)
    if @household.save
      redirect_to @household, notice: "Household added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @household.update(household_params)
      redirect_to @household, notice: "Saved. #{"The new address will be located shortly." if @household.saved_changes.keys.intersect?(Geocodable::ADDRESS_ATTRIBUTES)}"
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @household.destroy!
    redirect_to households_path, notice: "Household removed. Its people were kept.", status: :see_other
  end

  private
    def set_household
      @household = authorize policy_scope(Household).find(params.expect(:id))
    end

    def household_params
      params.expect(household: %i[ name address_line1 address_line2 city region postal_code country ])
    end
end

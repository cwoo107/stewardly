class CampusesController < ApplicationController
  before_action :set_campus, only: %i[ edit update destroy ]

  def index
    authorize Campus
    @campuses = policy_scope(Campus).ordered
  end

  def new
    @campus = authorize Campus.new
  end

  def create
    @campus = authorize Campus.new(campus_params)
    if @campus.save
      redirect_to campuses_path, notice: "Campus added. Its location will be looked up shortly."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @campus.update(campus_params)
      redirect_to campuses_path, notice: "Campus saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @campus.destroy!
    redirect_to campuses_path, notice: "Campus removed.", status: :see_other
  end

  private
    def set_campus
      @campus = authorize policy_scope(Campus).find(params.expect(:id))
    end

    def campus_params
      params.expect(campus: %i[ name address_line1 address_line2 city region postal_code country ])
    end
end

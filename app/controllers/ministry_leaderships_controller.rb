class MinistryLeadershipsController < ApplicationController
  before_action :set_ministry

  def create
    leadership = authorize @ministry.ministry_leaderships.new(user: User.find(params.expect(ministry_leadership: [ :user_id ])[:user_id]))
    leadership.save!
    redirect_to @ministry, notice: "#{leadership.user.name} now leads #{@ministry.name}.", status: :see_other
  end

  def destroy
    leadership = authorize @ministry.ministry_leaderships.find(params.expect(:id))
    leadership.destroy!
    redirect_to @ministry, notice: "#{leadership.user.name} no longer leads #{@ministry.name}.", status: :see_other
  end

  private
    def set_ministry
      @ministry = Ministry.find(params.expect(:ministry_id))
    end
end

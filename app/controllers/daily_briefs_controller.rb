# Rebuilding your brief now, and turning the 6am email on or off.
class DailyBriefsController < ApplicationController
  def create
    authorize Insight, :index?
    Insights::Brief.new(Current.user).build!
    redirect_to root_path, notice: "Your brief is up to date."
  end

  def update
    authorize Insight, :index?
    Current.user.update!(brief_email: params.expect(:brief_email) == "1")
    redirect_to root_path, notice: Current.user.brief_email? ? "You'll get your brief by email at 6am." : "Brief emails are off."
  end
end

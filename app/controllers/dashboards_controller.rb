class DashboardsController < ApplicationController
  def show
    authorize :dashboard
    return redirect_to member_root_path unless Current.user.admin_area?

    if Current.user.can?(:view_insights)
      @brief = DailyBrief.find_by(user: Current.user, date: Current.church.today)
      @insights = @brief&.insights.presence || Insights::Ranking.new(Current.user).insights(limit: 8)
      @open_count = Insight.open.visible_to(Current.user).count
    end
    @pinned = SavedReport.pinned.where(user: Current.user).order(:title) if Current.user.can?(:use_reports)
  end
end

class DashboardsController < ApplicationController
  def show
    authorize :dashboard
    redirect_to member_root_path unless Current.user.admin_area?
  end
end

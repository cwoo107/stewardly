class InsightsController < ApplicationController
  before_action :set_insight, except: :index

  def index
    authorize Insight
    scope = policy_scope(Insight).includes(:subject)
    @status = params[:status].presence_in(%w[ open snoozed resolved dismissed ]) || "open"
    scope = scope.where(status: @status)
    scope = scope.mine(Current.user) if params[:mine].present?
    scope = scope.where(kind: params[:kind]) if params[:kind].present?
    scope = scope.where(severity: params[:severity]) if Insight.severities.key?(params[:severity])
    @pagy, @insights = pagy(@status == "open" ? scope.most_severe_first : scope.order(updated_at: :desc))
    @kinds = policy_scope(Insight).live.distinct.pluck(:kind)
  end

  def resolve
    @insight.resolve!
    respond("Marked done.")
  end

  def dismiss
    @insight.dismiss!
    respond("Dismissed. It won't come back unless the situation changes and returns.")
  end

  def snooze
    days = params[:days].to_i.clamp(1, 60)
    @insight.snooze!(Current.church.today + days)
    respond("Snoozed until #{l(Current.church.today + days, format: :long)}.")
  end

  def assign
    owner = User.find(params.expect(:owner_id))
    task = @insight.assign_as_task!(owner:)
    respond("Task created for #{owner.name}.", task)
  end

  private
    def set_insight
      @insight = authorize Insight.find(params.expect(:id))
    end

    def respond(notice, _task = nil)
      redirect_back_or_to insights_path, notice:, status: :see_other
    end
end

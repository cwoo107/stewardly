class SuppressionsController < ApplicationController
  def index
    authorize Suppression
    scope = policy_scope(Suppression).includes(:email_topic).recent_first
    scope = scope.where("email ILIKE ?", "%#{Suppression.sanitize_sql_like(params[:q])}%") if params[:q].present?
    scope = scope.where(reason: params[:reason]) if Suppression.reasons.key?(params[:reason])
    @pagy, @suppressions = pagy(scope)
    @suppression = Suppression.new(reason: :manual)
  end

  def create
    @suppression = authorize Suppression.new(params.expect(suppression: %i[ email note email_topic_id ]).merge(reason: :manual, source: Current.user.name))
    if @suppression.save
      redirect_to suppressions_path, notice: "#{@suppression.email} won't get #{@suppression.email_topic ? "#{@suppression.email_topic.name} campaigns" : "email from the church"}."
    else
      redirect_to suppressions_path, alert: @suppression.errors.full_messages.to_sentence
    end
  end

  def destroy
    suppression = authorize Suppression.find(params.expect(:id))
    suppression.destroy!
    redirect_to suppressions_path, notice: "#{suppression.email} can get email again.", status: :see_other
  end
end

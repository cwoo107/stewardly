class SavedReportsController < ApplicationController
  before_action :set_report, only: %i[ show update destroy rerun ]

  def index
    authorize :report, :index?
    @reports = policy_scope(SavedReport, policy_scope_class: ReportPolicy::Scope).recent_first
  end

  def show
    @report.rerun! if @report.stale?
  end

  # From an assistant answer (message_id) or a metric run (tool + arguments).
  def create
    authorize :report, :create?
    report = if params[:message_id]
      message = ReportMessage.joins(:report_conversation).where(report_conversations: { user_id: Current.user.id }).find(params[:message_id])
      SavedReport.new(user: Current.user, title: message.question.to_s.truncate(80), question: message.question, summary: message.content,
        tool_calls: message.tool_calls.select { |call| call["result"] }.map { |call| { "name" => call["name"], "arguments" => call["requested"] || call["arguments"] } })
    else
      tool = Reports::Tools.find(params.expect(:tool), user: Current.user, church: Current.church) or raise ActiveRecord::RecordNotFound
      SavedReport.new(user: Current.user, title: tool.title, tool_calls: [ { "name" => tool.tool_name, "arguments" => params.fetch(:arguments, {}).permit!.to_h } ])
    end
    if report.save
      report.rerun!
      redirect_to report, notice: "Report saved."
    else
      redirect_back_or_to saved_reports_path, alert: report.errors.full_messages.to_sentence
    end
  end

  def update
    @report.update!(params.expect(saved_report: %i[ title pinned ]))
    redirect_back_or_to @report, notice: @report.pinned? ? "Pinned to your dashboard." : "Saved."
  end

  def destroy
    @report.destroy!
    redirect_to saved_reports_path, notice: "Report deleted.", status: :see_other
  end

  def rerun
    @report.rerun!
    redirect_back_or_to @report, notice: "Updated with today's numbers."
  end

  private
    def set_report
      @report = SavedReport.find(params.expect(:id))
      authorize @report, :"#{action_name == "rerun" ? "rerun" : action_name}?", policy_class: ReportPolicy
    end
end

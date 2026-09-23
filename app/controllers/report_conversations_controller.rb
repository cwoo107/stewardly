class ReportConversationsController < ApplicationController
  def index
    authorize :report, :index?
    @conversations = policy_scope(ReportConversation, policy_scope_class: ReportPolicy::Scope).recent_first.limit(30)
    @ai = Assistant::Client.new(church: Current.church, user: Current.user, purpose: "report_assistant").available?
  end

  def show
    @conversation = ReportConversation.find(params.expect(:id))
    authorize @conversation, :show?, policy_class: ReportPolicy
  end

  def create
    authorize :report, :create?
    question = params.expect(:question).to_s.strip
    return redirect_to(report_conversations_path, alert: "Ask a question first.") if question.blank?

    conversation = ReportConversation.create!(user: Current.user, title: question.truncate(80))
    conversation.ask!(question)
    redirect_to conversation
  end
end

class ReportMessagesController < ApplicationController
  before_action :set_conversation

  def create
    question = params.expect(:question).to_s.strip
    @conversation.ask!(question) if question.present?
    redirect_to @conversation
  end

  # The answer's frame; the page reloads it until the answer is ready.
  def show
    @message = @conversation.messages.find(params.expect(:id))
    render partial: "report_messages/message", locals: { message: @message }
  end

  private
    def set_conversation
      @conversation = ReportConversation.find(params.expect(:report_conversation_id))
      authorize @conversation, :show?, policy_class: ReportPolicy
    end
end

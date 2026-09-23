# The approval queue: messages workflows drafted, waiting for a person to review.
class MessageDraftsController < ApplicationController
  before_action :set_draft, only: %i[ edit update reject ]

  def index
    authorize MessageDraft
    status = params[:status].presence_in(MessageDraft.statuses.keys) || "pending"
    scope = policy_scope(MessageDraft).includes(:person, workflow_step_execution: { workflow_run: :workflow }).where(status:)
    scope = status == "pending" ? scope.oldest_first : scope.order(reviewed_at: :desc)
    @status = status
    @pagy, @drafts = pagy(scope)
  end

  def edit
  end

  def update
    @draft.approve!(subject: params.dig(:message_draft, :subject).presence || @draft.subject, body: params.dig(:message_draft, :body))
    redirect_to message_drafts_path, notice: "Sent to #{@draft.person.name}."
  rescue ArgumentError => error
    flash.now[:alert] = error.message
    @draft.assign_attributes(params.expect(message_draft: %i[ subject body ]))
    render :edit, status: :unprocessable_content
  end

  def reject
    @draft.reject!(note: params[:note])
    redirect_to message_drafts_path, notice: "Not sent.", status: :see_other
  end

  private
    def set_draft
      @draft = authorize MessageDraft.find(params.expect(:id))
    end
end

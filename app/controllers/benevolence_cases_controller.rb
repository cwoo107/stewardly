# Benevolence cases. Opening a case (or its history) is recorded in the audit log; the
# list only shows who, what kind of need, and how much, never the private text.
class BenevolenceCasesController < ApplicationController
  before_action :set_case, only: %i[ show edit update decide ]

  def index
    authorize BenevolenceCase
    Form::Starters.install!(only: "help") # churches set up before benevolence existed get the draft request form
    @tab = params[:tab].presence_in(%w[ open mine approved closed all ]) || "open"
    scope = policy_scope(BenevolenceCase).includes(:person, :assigned_to).recent_first
    scope = case @tab
    when "open" then scope.where(status: %w[ submitted under_review ])
    when "mine" then scope.open.where(assigned_to: Current.user)
    when "approved" then scope.approved
    when "closed" then scope.where(status: %w[ denied fulfilled ])
    else scope
    end
    @pagy, @cases = pagy(scope)
  end

  def show
    AuditEvent.record!(action: "benevolence_case.viewed", auditable: @case)
    @flags = @case.policy_check.flags
    @history = Benevolence::History.new(@case)
    @decision = @case.decision
    # Not built through the association, so it doesn't show up in the payments list.
    @disbursement = BenevolenceDisbursement.new(paid_on: Current.church.today, amount_cents: @case.remaining_cents.nonzero?, payee_type: "landlord", method: "check",
      fund: Fund.for_benevolence.alphabetical.first)
  end

  def new
    person = Person.unmerged.find_by(id: params[:person_id])
    return redirect_to(benevolence_cases_path, alert: "Find the person first.") unless person

    @case = authorize BenevolenceCase.new(person:, assigned_to: Current.user, need_category: "rent")
  end

  def create
    @case = authorize BenevolenceCase.new(case_params.merge(created_by: Current.user, source: :staff))
    if @case.save
      AuditEvent.record!(action: "benevolence_case.opened", auditable: @case)
      redirect_to @case, notice: "Case opened."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @case.update(case_params.except(:person_id))
      AuditEvent.record!(action: "benevolence_case.updated", auditable: @case, metadata: { "changed" => @case.saved_changes.keys - %w[ updated_at ] })
      redirect_to @case, notice: "Case saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def decide
    decision = params.expect(:decision).presence_in(%w[ approve deny ]) or raise ActionController::BadRequest
    @case.decision.record!(user: Current.user, decision:, amount_cents: Money.parse_cents(params[:amount]), note: params[:note].presence)
    redirect_to @case, notice: decision == "approve" ? "Your approval is recorded." : "Your decision to deny is recorded."
  rescue Benevolence::Decision::NotAllowed, ActiveRecord::RecordInvalid => error
    redirect_to @case, alert: error.respond_to?(:record) ? error.record.errors.full_messages.to_sentence : error.message
  end

  def report
    authorize BenevolenceCase, :report?
    @report = Benevolence::Report.new(Current.church)
  end

  private
    def set_case
      @case = BenevolenceCase.find(params.expect(:id))
      authorize @case, action_name == "decide" ? :decide? : :"#{action_name}?"
    end

    def case_params
      attributes = params.expect(benevolence_case: %i[ person_id need_category summary circumstances requested assigned_to_id ])
      requested = attributes.delete(:requested)
      requested.nil? ? attributes : attributes.merge(requested_cents: Money.parse_cents(requested).to_i)
    end
end

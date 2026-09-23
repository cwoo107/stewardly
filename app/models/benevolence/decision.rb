# Approving or denying a case.
#
# At or below the church's threshold, one person with approve_benevolence decides. Above
# it, the church's required number of approvals (1 or 2) must come from people who
# didn't open and aren't handling the case. Any deny from an eligible approver denies
# the case; the approved amount is the lowest one approved.
class Benevolence::Decision
  class NotAllowed < StandardError; end

  def initialize(kase)
    @case = kase
    @church = kase.church
  end

  def amount_cents = @case.requested_cents
  def above_threshold? = amount_cents > @church.benevolence_approval_threshold_cents
  def approvals_required = above_threshold? ? @church.benevolence_approvals_required : 1
  def approvals = @case.approvals.approve
  def approvals_needed = [ approvals_required - approvals.count, 0 ].max

  # Why this user can't decide, or nil when they can.
  def ineligibility(user)
    return "You don't have permission to approve benevolence requests" unless user&.can?(:approve_benevolence)
    return "This case is already #{@case.status.humanize.downcase}" unless @case.submitted? || @case.under_review?
    return "You've already decided on this case" if @case.approvals.exists?(user:)
    if above_threshold? && [ @case.created_by_id, @case.assigned_to_id ].include?(user.id)
      return "Requests above #{Money.format(@church.benevolence_approval_threshold_cents)} need approval from someone not handling the case"
    end

    nil
  end

  def eligible?(user) = ineligibility(user).nil?

  def record!(user:, decision:, amount_cents: nil, note: nil)
    @case.with_lock do
      reason = ineligibility(user)
      raise NotAllowed, reason if reason

      approval = @case.approvals.create!(user:, decision:, amount_cents: decision.to_s == "approve" ? amount_cents : nil, note:)
      AuditEvent.record!(action: decision.to_s == "approve" ? "benevolence.approval_recorded" : "benevolence.denial_recorded", auditable: @case, metadata: { "amount_cents" => approval.amount_cents })
      settle!(user, note)
      approval
    end
  end

  private
    def settle!(user, note)
      if @case.approvals.deny.exists?
        @case.update!(status: :denied, decided_by: user, decided_at: Time.current, decision_note: note)
        AuditEvent.record!(action: "benevolence.denied", auditable: @case)
      elsif approvals_needed.zero?
        @case.update!(status: :approved, approved_cents: approvals.minimum(:amount_cents), decided_by: user, decided_at: Time.current, decision_note: note)
        AuditEvent.record!(action: "benevolence.approved", auditable: @case, metadata: { "approved_cents" => @case.approved_cents })
      else
        @case.update!(status: :under_review)
      end
    end
end

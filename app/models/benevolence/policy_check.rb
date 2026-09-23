# Flags for a case, from the church's benevolence settings. Counts cover the rolling
# last 12 months, for the household (or just the person, per church setting).
class Benevolence::PolicyCheck
  Flag = Data.define(:key, :label, :severity) # severity: "warning" | "info"

  def initialize(kase, today: kase.church.today)
    @case = kase
    @church = kase.church
    @today = today
  end

  def scope_label = by_household? ? "household" : "person"

  def related_cases
    base = BenevolenceCase.where.not(id: @case.id)
    by_household? ? base.where(household_id: @case.household_id) : base.where(person_id: @case.person_id)
  end

  def paid_last_year_cents
    BenevolenceDisbursement.where(benevolence_case_id: related_cases.select(:id).or(BenevolenceCase.where(id: @case.id).select(:id)))
      .where(paid_on: (@today - 365)..).sum(:amount_cents)
  end

  def requests_last_year = related_cases.where(created_at: (@today - 365).beginning_of_day..).count

  def flags
    flags = []
    limit = @church.benevolence_annual_limit_cents
    upcoming = @case.approved? ? @case.remaining_cents : (@case.open? ? @case.requested_cents : 0)
    if limit.positive? && paid_last_year_cents + upcoming > limit
      flags << Flag.new("over_limit", "Over the #{Money.format(limit)} limit per #{scope_label} in 12 months " \
        "(#{Money.format(paid_last_year_cents)} paid so far)", "warning")
    end
    if (count = requests_last_year).positive?
      flags << Flag.new("repeat", "#{ActionController::Base.helpers.pluralize(count, "other request")} from this #{scope_label} in 12 months", count > 1 ? "warning" : "info")
    end
    if @case.open? && related_cases.open.exists?
      flags << Flag.new("open_elsewhere", "Another open case for this #{scope_label}", "warning")
    end
    if (@case.submitted? || @case.under_review?) && @case.decision.above_threshold?
      flags << Flag.new("needs_approvals", "Above #{Money.format(@church.benevolence_approval_threshold_cents)}: needs " \
        "#{ActionController::Base.helpers.pluralize(@case.decision.approvals_required, "approval")} from someone not handling the case", "info")
    end
    flags
  end

  private
    def by_household? = @church.benevolence_limit_scope == "household" && @case.household_id.present?
end
